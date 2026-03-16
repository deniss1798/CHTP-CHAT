CREATE DATABASE Messenger;

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_avatars (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    upload_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, /* Дата загрузки */
    file_path VARCHAR(255) UNIQUE NOT NULL, /* Путь к файлу с аватаром */
    is_main BOOLEAN NOT NULL DEFAULT true /* у юзера может быть много разных аватаров. один из них точно главный. когда юзер загружает новый аватар, он по умолчанию главный */
)

CREATE TABLE chats (
    id BIGSERIAL PRIMARY KEY,
    type VARCHAR(20) NOT NULL,
    title VARCHAR(255),
    created_by BIGINT REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE chat_members (
    id BIGSERIAL PRIMARY KEY,
    chat_id BIGINT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(chat_id, user_id)
);

CREATE TABLE messages (
    id BIGSERIAL PRIMARY KEY,
    chat_id BIGINT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    sender_id BIGINT NOT NULL REFERENCES users(id),
    text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP /* дата обновления сообщения, возможно будем редактировать сообщения */
    is_updated BOOLEAN DEFAULT false /* по умолчанию сообщение естественно не отредактировано. данный флаг нужен чтобы на UI проставлять метку к сообщению что его редактировали */
);



CREATE INDEX idx_messages_chat_id
ON messages(chat_id);

CREATE INDEX idx_chat_members_user_id
ON chat_members(user_id);

CREATE INDEX idx_chat_members_chat_id
ON chat_members(chat_id);