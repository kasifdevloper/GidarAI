import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';

typedef ChatCompletionStreamFactory = Stream<String> Function({
  required ProviderKeys providerKeys,
  required List<CustomProviderConfig> customProviders,
  required ModelOption model,
  required ChatRoutingMode routingMode,
  required List<AiProviderType> enabledProviders,
  required String systemPrompt,
  required List<ChatMessage> history,
  void Function(AiProviderType provider, ModelOption model)? onProviderSelected,
  void Function(String message)? onProviderNotice,
});

class ChatStreamingRequest {
  const ChatStreamingRequest({
    required this.providerKeys,
    required this.customProviders,
    required this.model,
    required this.routingMode,
    required this.enabledProviders,
    required this.systemPrompt,
    required this.history,
  });

  final ProviderKeys providerKeys;
  final List<CustomProviderConfig> customProviders;
  final ModelOption model;
  final ChatRoutingMode routingMode;
  final List<AiProviderType> enabledProviders;
  final String systemPrompt;
  final List<ChatMessage> history;
}

class ChatStreamingCoordinator {
  ChatStreamingCoordinator({
    required ChatCompletionStreamFactory streamFactory,
    Duration idleTimeout = const Duration(seconds: 12),
    Duration revealTick = const Duration(milliseconds: 32),
  })  : _streamFactory = streamFactory,
        _idleTimeout = idleTimeout,
        _revealTick = revealTick;

  final ChatCompletionStreamFactory _streamFactory;
  final Duration _idleTimeout;
  final Duration _revealTick;

  StreamSubscription<String>? _streamingSubscription;
  Timer? _streamingIdleTimer;
  Timer? _draftRevealTimer;
  Completer<void>? _runCompleter;
  Completer<void>? _draftDrainCompleter;
  bool _isFinalizingStreaming = false;
  bool _isStreaming = false;
  bool _isWaitingForAssistant = false;
  bool _isTypingAssistant = false;
  String _streamingDraft = '';
  String _targetStreamingDraft = '';

  bool get isStreaming => _isStreaming;
  bool get isWaitingForAssistant => _isWaitingForAssistant;
  bool get isTypingAssistant => _isTypingAssistant;
  String get streamingDraft => _streamingDraft;

  /// Call BEFORE adding user message — sets typing state so UI shows
  /// user message + typing indicator in a SINGLE rebuild (no blink).
  void prepareForStreaming() {
    _isWaitingForAssistant = true;
    _isTypingAssistant = false;
    _streamingDraft = '';
    _targetStreamingDraft = '';
  }

  Future<void> start({
    required ChatStreamingRequest request,
    required Future<void> Function(String reply) onAssistantReply,
    required Future<void> Function() onSettled,
    required void Function(String message) onErrorMessage,
    required VoidCallback onStateChanged,
    void Function(AiProviderType provider, ModelOption model)?
        onProviderSelected,
    void Function(String message)? onProviderNotice,
    String emptyResponseMessage =
        'Model returned an empty response. Try another free model.',
  }) async {
    _isStreaming = true;
    _isFinalizingStreaming = false;
    // isWaitingForAssistant already set by prepareForStreaming()
    _isTypingAssistant = false;
    _clearStreamingIdleTimer();
    // No onStateChanged() here — already called in sendMessage()

    try {
      final completer = Completer<void>();
      _runCompleter = completer;
      _streamingSubscription = _streamFactory(
        providerKeys: request.providerKeys,
        customProviders: request.customProviders,
        model: request.model,
        routingMode: request.routingMode,
        enabledProviders: request.enabledProviders,
        systemPrompt: request.systemPrompt,
        history: request.history,
        onProviderSelected: onProviderSelected,
        onProviderNotice: onProviderNotice,
      ).listen(
        (piece) {
          if (piece.isEmpty) return;
          if (_isWaitingForAssistant) {
            _isWaitingForAssistant = false;
            _isTypingAssistant = true;
            onStateChanged();
          }
          _targetStreamingDraft += piece;
          _ensureDraftRevealTimer(onStateChanged);
          _armStreamingIdleTimer(
            onAssistantReply: onAssistantReply,
            onSettled: onSettled,
            onErrorMessage: onErrorMessage,
            onStateChanged: onStateChanged,
            emptyResponseMessage: emptyResponseMessage,
          );
        },
        onError: (Object error, StackTrace stackTrace) async {
          _clearStreamingIdleTimer();
          onErrorMessage(error.toString().replaceFirst('Exception: ', ''));
          await _finish(
            onSettled: onSettled,
            onStateChanged: onStateChanged,
            saveDraft: false,
          );
          _completeRun();
        },
        onDone: () async {
          _clearStreamingIdleTimer();
          await _finalizeStreamingDraft(
            onAssistantReply: onAssistantReply,
            onSettled: onSettled,
            onErrorMessage: onErrorMessage,
            onStateChanged: onStateChanged,
            emptyResponseMessage: emptyResponseMessage,
          );
          _completeRun();
        },
        cancelOnError: true,
      );
      await completer.future;
    } on Object catch (error) {
      onErrorMessage(error.toString().replaceFirst('Exception: ', ''));
      await _finish(
        onSettled: onSettled,
        onStateChanged: onStateChanged,
        saveDraft: false,
      );
    }
  }

  Future<void> stop({
    required Future<void> Function(String reply) onAssistantReply,
    required Future<void> Function() onSettled,
    required VoidCallback onStateChanged,
  }) async {
    if (!_isStreaming) return;
    _clearStreamingIdleTimer();
    _clearDraftRevealTimer();
    _isWaitingForAssistant = false;
    _isTypingAssistant = false;
    onStateChanged();
    await _streamingSubscription?.cancel();
    _streamingSubscription = null;
    final partialReply = _targetStreamingDraft.trim();
    if (partialReply.isNotEmpty) {
      await onAssistantReply('$partialReply\n\n*(stopped)*');
    }
    await _finish(
      onSettled: onSettled,
      onStateChanged: onStateChanged,
      saveDraft: false,
    );
    _completeRun();
  }

  Future<void> reset({
    required Future<void> Function() onSettled,
    required VoidCallback onStateChanged,
  }) async {
    _clearStreamingIdleTimer();
    _clearDraftRevealTimer();
    await _streamingSubscription?.cancel();
    _streamingSubscription = null;
    _isStreaming = false;
    _isWaitingForAssistant = false;
    _isTypingAssistant = false;
    _isFinalizingStreaming = false;
    _streamingDraft = '';
    _targetStreamingDraft = '';
    await onSettled();
    onStateChanged();
    _completeRun();
  }

  Future<void> _finalizeStreamingDraft({
    required Future<void> Function(String reply) onAssistantReply,
    required Future<void> Function() onSettled,
    required void Function(String message) onErrorMessage,
    required VoidCallback onStateChanged,
    required String emptyResponseMessage,
  }) async {
    if (_isFinalizingStreaming) return;
    _isFinalizingStreaming = true;
    _clearStreamingIdleTimer();
    await _drainVisibleDraft(onStateChanged);
    final fullReply = _targetStreamingDraft.trim();
    if (fullReply.isNotEmpty) {
      _isWaitingForAssistant = false;
      _isTypingAssistant = false;
      _streamingDraft = '';
      _targetStreamingDraft = '';
      onStateChanged();
      await onAssistantReply(fullReply);
      await _finish(
        onSettled: onSettled,
        onStateChanged: onStateChanged,
        saveDraft: false,
      );
      return;
    }
    onErrorMessage(emptyResponseMessage);
    await _finish(
      onSettled: onSettled,
      onStateChanged: onStateChanged,
      saveDraft: false,
    );
  }

  void _armStreamingIdleTimer({
    required Future<void> Function(String reply) onAssistantReply,
    required Future<void> Function() onSettled,
    required void Function(String message) onErrorMessage,
    required VoidCallback onStateChanged,
    required String emptyResponseMessage,
  }) {
    _streamingIdleTimer?.cancel();
    _streamingIdleTimer = Timer(_idleTimeout, () {
      if (!_isStreaming || _targetStreamingDraft.trim().isEmpty) {
        return;
      }
      unawaited(() async {
        await _streamingSubscription?.cancel();
        _streamingSubscription = null;
        await _finalizeStreamingDraft(
          onAssistantReply: onAssistantReply,
          onSettled: onSettled,
          onErrorMessage: onErrorMessage,
          onStateChanged: onStateChanged,
          emptyResponseMessage: emptyResponseMessage,
        );
      }());
    });
  }

  Future<void> _finish({
    required Future<void> Function() onSettled,
    required VoidCallback onStateChanged,
    required bool saveDraft,
  }) async {
    _clearStreamingIdleTimer();
    _clearDraftRevealTimer();
    _streamingSubscription = null;
    _isStreaming = false;
    _isWaitingForAssistant = false;
    _isTypingAssistant = false;
    _isFinalizingStreaming = false;
    if (!saveDraft) {
      _streamingDraft = '';
      _targetStreamingDraft = '';
    }
    await onSettled();
    onStateChanged();
    _completeRun();
  }

  void _clearStreamingIdleTimer() {
    _streamingIdleTimer?.cancel();
    _streamingIdleTimer = null;
  }

  void _ensureDraftRevealTimer(VoidCallback onStateChanged) {
    if (_draftRevealTimer != null) return;
    _draftRevealTimer = Timer.periodic(_revealTick, (_) {
      final visibleLength = _streamingDraft.length;
      final targetLength = _targetStreamingDraft.length;
      final backlog = targetLength - visibleLength;
      if (backlog <= 0) {
        _clearDraftRevealTimer();
        return;
      }

      final nextLength =
          (visibleLength + _nextRevealStep(backlog)).clamp(0, targetLength);
      _streamingDraft = _targetStreamingDraft.substring(0, nextLength);
      onStateChanged();

      if (_streamingDraft.length >= _targetStreamingDraft.length) {
        _completeDraftDrain();
        _clearDraftRevealTimer();
      }
    });
  }

  int _nextRevealStep(int backlog) {
    if (backlog >= 1200) return 160;
    if (backlog >= 700) return 100;
    if (backlog >= 320) return 60;
    if (backlog >= 180) return 36;
    if (backlog >= 90) return 20;
    if (backlog >= 40) return 10;
    if (backlog >= 16) return 6;
    return 3;
  }

  Future<void> _drainVisibleDraft(VoidCallback onStateChanged) async {
    if (_streamingDraft.length >= _targetStreamingDraft.length) return;
    _ensureDraftRevealTimer(onStateChanged);
    final completer = _draftDrainCompleter ??= Completer<void>();
    await completer.future;
  }

  void _clearDraftRevealTimer() {
    _draftRevealTimer?.cancel();
    _draftRevealTimer = null;
    if (_streamingDraft.length >= _targetStreamingDraft.length) {
      _completeDraftDrain();
    }
  }

  void _completeDraftDrain() {
    if (_draftDrainCompleter case final completer?
        when !completer.isCompleted) {
      completer.complete();
    }
    _draftDrainCompleter = null;
  }

  void _completeRun() {
    _completeDraftDrain();
    if (_runCompleter case final completer? when !completer.isCompleted) {
      completer.complete();
    }
    _runCompleter = null;
  }

  void dispose() {
    _clearStreamingIdleTimer();
    _clearDraftRevealTimer();
    _streamingSubscription?.cancel();
  }
}
