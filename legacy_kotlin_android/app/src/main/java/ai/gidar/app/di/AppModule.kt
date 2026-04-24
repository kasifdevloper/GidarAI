package ai.gidar.app.di

import android.content.Context
import androidx.room.Room
import ai.gidar.app.R
import ai.gidar.app.data.local.ChatDao
import ai.gidar.app.data.local.ChatDatabase
import ai.gidar.app.data.local.SecureStorage
import ai.gidar.app.data.remote.OpenRouterApi
import ai.gidar.app.data.repository.SettingsRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideChatDatabase(@ApplicationContext context: Context): ChatDatabase {
        return Room.databaseBuilder(
            context,
            ChatDatabase::class.java,
            ChatDatabase.getDatabaseName(context)
        ).addMigrations(ChatDatabase.MIGRATION_1_2).build()
    }

    @Provides
    fun provideChatDao(database: ChatDatabase): ChatDao = database.chatDao()

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        val logging = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }
        return OkHttpClient.Builder()
            .addInterceptor(logging)
            .build()
    }

    @Provides
    @Singleton
    fun provideOpenRouterApi(@ApplicationContext context: Context, okHttpClient: OkHttpClient): OpenRouterApi {
        return Retrofit.Builder()
            .baseUrl(context.getString(R.string.openrouter_base_url))
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(OpenRouterApi::class.java)
    }

    @Provides
    @Singleton
    fun provideSecureStorage(@ApplicationContext context: Context): SecureStorage {
        return SecureStorage(context)
    }
}
