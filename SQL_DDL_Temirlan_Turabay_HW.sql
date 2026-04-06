/*
Create a separate physical database and schema and give it an appropriate
 domain-related name. Use the relational model you've created while 
 studying 'DB Basics module. Task: designing a logical data model on 
 the chosen topic'. Make sure you have made any changes to your model 
 after your mentor's comments. 

 Ensure your physical database is in 3NF. Do not add extra columns, 
 tables, or relations not specified in the logical model (if you made 
 any additions, you should adjust the logical model accordingly and 
 include comments explaining the reasons for those changes)

Use appropriate data types for each column (if the data type is different
 from what you specified in the logical module, explain in the comments 
 why you made the change). Please also indicate in the comments what 
 risks would result from choosing the wrong data type?

Apply DEFAULT values, and GENERATED ALWAYS AS columns as required.

Create relationships between tables using primary and foreign keys. 
Explain in the comments what happens if FK is missing

Apply five check constraints across the tables to restrict certain values, including
date to be inserted, which must be greater than January 1, 2000
inserted measured value that cannot be negative
inserted value that can only be a specific value (as an example of gender)
unique
not null
+ For each constraint explain in the comments what incorrect data it prevents, 
what would happen without it.

Create tables in the correct DDL order: parent tables before child tables to avoid 
foreign key errors. Explain in the comments why order matters, what error 
would occur if order is wrong
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS social_media_core;
SET search_path TO social_media_core, public;

CREATE TABLE IF NOT EXISTS users (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY,
    username VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash TEXT NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    personal_info TEXT,
    location_info VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_users PRIMARY KEY (user_id),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT ck_users_user_id_positive CHECK (user_id > 0),
    CONSTRAINT ck_users_username_not_blank CHECK (btrim(username) <> ''),
    CONSTRAINT ck_users_email_not_blank CHECK (btrim(email) <> ''),
    CONSTRAINT ck_users_created_at_since_2000 CHECK (created_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS hashtags (
    hashtag_id BIGINT GENERATED ALWAYS AS IDENTITY,
    hashtag_name VARCHAR(255) NOT NULL,

    CONSTRAINT pk_hashtags PRIMARY KEY (hashtag_id),
    CONSTRAINT uq_hashtags_name UNIQUE (hashtag_name),
    CONSTRAINT ck_hashtags_id_positive CHECK (hashtag_id > 0),
    CONSTRAINT ck_hashtags_name_not_blank CHECK (btrim(hashtag_name) <> '')
);

CREATE TABLE IF NOT EXISTS user_profile_history (
    profile_history_id BIGINT GENERATED ALWAYS AS IDENTITY,
    user_id BIGINT NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    personal_info TEXT,
    location_info VARCHAR(255),
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_user_profile_history PRIMARY KEY (profile_history_id),
    CONSTRAINT fk_user_profile_history_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_user_profile_history_id_positive CHECK (profile_history_id > 0),
    CONSTRAINT ck_user_profile_history_changed_at_since_2000 CHECK (changed_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS privacy_setting (
    privacy_id BIGINT GENERATED ALWAYS AS IDENTITY,
    user_id BIGINT NOT NULL,
    profile_visibility VARCHAR(255) NOT NULL DEFAULT 'public',
    post_visibility VARCHAR(255) NOT NULL DEFAULT 'public',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_privacy_setting PRIMARY KEY (privacy_id),
    CONSTRAINT uq_privacy_setting_user UNIQUE (user_id),
    CONSTRAINT fk_privacy_setting_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_privacy_setting_id_positive CHECK (privacy_id > 0),
    CONSTRAINT ck_privacy_setting_profile_visibility
        CHECK (profile_visibility IN ('public', 'private', 'followers_only')),
    CONSTRAINT ck_privacy_setting_post_visibility
        CHECK (post_visibility IN ('public', 'private', 'followers_only')),
    CONSTRAINT ck_privacy_setting_updated_at_since_2000 CHECK (updated_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS privacy_setting_history (
    privacy_history_id BIGINT GENERATED ALWAYS AS IDENTITY,
    user_id BIGINT NOT NULL,
    profile_visibility VARCHAR(255) NOT NULL,
    post_visibility VARCHAR(255) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_privacy_setting_history PRIMARY KEY (privacy_history_id),
    CONSTRAINT fk_privacy_setting_history_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_privacy_setting_history_id_positive CHECK (privacy_history_id > 0),
    CONSTRAINT ck_privacy_setting_history_profile_visibility
        CHECK (profile_visibility IN ('public', 'private', 'followers_only')),
    CONSTRAINT ck_privacy_setting_history_post_visibility
        CHECK (post_visibility IN ('public', 'private', 'followers_only')),
    CONSTRAINT ck_privacy_setting_history_changed_at_since_2000 CHECK (changed_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS posts (
    post_id BIGINT GENERATED ALWAYS AS IDENTITY,
    user_id BIGINT NOT NULL,
    body TEXT,
    visibility VARCHAR(255) NOT NULL DEFAULT 'public',
    posted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_posts PRIMARY KEY (post_id),
    CONSTRAINT fk_posts_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_posts_id_positive CHECK (post_id > 0),
    CONSTRAINT ck_posts_visibility
        CHECK (visibility IN ('public', 'private', 'followers_only')),
    CONSTRAINT ck_posts_posted_at_since_2000 CHECK (posted_at > TIMESTAMP '2000-01-01 00:00:00'),
    CONSTRAINT ck_posts_not_completely_empty CHECK (body IS NULL OR btrim(body) <> '')
);

CREATE TABLE IF NOT EXISTS post_medias (
    media_id BIGINT GENERATED ALWAYS AS IDENTITY,
    post_id BIGINT NOT NULL,
    media_type VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_post_medias PRIMARY KEY (media_id),
    CONSTRAINT fk_post_medias_post
        FOREIGN KEY (post_id)
        REFERENCES posts (post_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_post_medias_id_positive CHECK (media_id > 0),
    CONSTRAINT ck_post_medias_media_type
        CHECK (media_type IN ('image', 'video', 'gif')),
    CONSTRAINT ck_post_medias_url_not_blank CHECK (btrim(url) <> ''),
    CONSTRAINT ck_post_medias_added_at_since_2000 CHECK (added_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS post_hashtags (
    post_hashtag_id BIGINT GENERATED ALWAYS AS IDENTITY,
    post_id BIGINT NOT NULL,
    hashtag_id BIGINT NOT NULL,
    tagged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_post_hashtags PRIMARY KEY (post_hashtag_id),
    CONSTRAINT uq_post_hashtags_post_hashtag UNIQUE (post_id, hashtag_id),
    CONSTRAINT fk_post_hashtags_post
        FOREIGN KEY (post_id)
        REFERENCES posts (post_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_post_hashtags_hashtag
        FOREIGN KEY (hashtag_id)
        REFERENCES hashtags (hashtag_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_post_hashtags_id_positive CHECK (post_hashtag_id > 0),
    CONSTRAINT ck_post_hashtags_tagged_at_since_2000 CHECK (tagged_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS likes (
    like_id BIGINT GENERATED ALWAYS AS IDENTITY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    liked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_likes PRIMARY KEY (like_id),
    CONSTRAINT uq_likes_user_post UNIQUE (user_id, post_id),
    CONSTRAINT fk_likes_post
        FOREIGN KEY (post_id)
        REFERENCES posts (post_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_likes_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_likes_id_positive CHECK (like_id > 0),
    CONSTRAINT ck_likes_liked_at_since_2000 CHECK (liked_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS comments (
    comment_id BIGINT GENERATED ALWAYS AS IDENTITY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    parent_comment_id BIGINT,
    body TEXT NOT NULL,
    commented_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_comments PRIMARY KEY (comment_id),
    CONSTRAINT fk_comments_post
        FOREIGN KEY (post_id)
        REFERENCES posts (post_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_comments_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_comments_parent_comment
        FOREIGN KEY (parent_comment_id)
        REFERENCES comments (comment_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_comments_id_positive CHECK (comment_id > 0),
    CONSTRAINT ck_comments_body_not_blank CHECK (btrim(body) <> ''),
    CONSTRAINT ck_comments_commented_at_since_2000 CHECK (commented_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS follows (
    follow_id BIGINT GENERATED ALWAYS AS IDENTITY,
    follower_id BIGINT NOT NULL,
    followee_id BIGINT NOT NULL,
    followed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_follows PRIMARY KEY (follow_id),
    CONSTRAINT uq_follows_follower_followee UNIQUE (follower_id, followee_id),
    CONSTRAINT fk_follows_follower
        FOREIGN KEY (follower_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_follows_followee
        FOREIGN KEY (followee_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_follows_id_positive CHECK (follow_id > 0),
    CONSTRAINT ck_follows_no_self_follow CHECK (follower_id <> followee_id),
    CONSTRAINT ck_follows_followed_at_since_2000 CHECK (followed_at > TIMESTAMP '2000-01-01 00:00:00')
);

CREATE TABLE IF NOT EXISTS shares (
    share_id BIGINT GENERATED ALWAYS AS IDENTITY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    shared_note TEXT,
    shared_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_shares PRIMARY KEY (share_id),
    CONSTRAINT fk_shares_post
        FOREIGN KEY (post_id)
        REFERENCES posts (post_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_shares_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT ck_shares_id_positive CHECK (share_id > 0),
    CONSTRAINT ck_shares_shared_note_not_blank CHECK (shared_note IS NULL OR btrim(shared_note) <> ''),
    CONSTRAINT ck_shares_shared_at_since_2000 CHECK (shared_at > TIMESTAMP '2000-01-01 00:00:00')
);

/*Indeces*/
CREATE INDEX IF NOT EXISTS idx_user_profile_history_user_id ON user_profile_history (user_id);
CREATE INDEX IF NOT EXISTS idx_privacy_setting_history_user_id ON privacy_setting_history (user_id);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts (user_id);
CREATE INDEX IF NOT EXISTS idx_post_medias_post_id ON post_medias (post_id);
CREATE INDEX IF NOT EXISTS idx_post_hashtags_post_id ON post_hashtags (post_id);
CREATE INDEX IF NOT EXISTS idx_post_hashtags_hashtag_id ON post_hashtags (hashtag_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes (post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments (post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments (user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_comment_id ON comments (parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_follows_followee_id ON follows (followee_id);
CREATE INDEX IF NOT EXISTS idx_shares_post_id ON shares (post_id);
CREATE INDEX IF NOT EXISTS idx_shares_user_id ON shares (user_id);

/*
After creating tables and adding all constraints, populate the tables 
with sample data generated, ensuring each table has at least two rows 
(for a total of 20+ rows in all the tables). Use INSERT statements with
 ON CONFLICT DO NOTHING or WHERE NOT EXISTS to avoid duplicates. 
 Avoid hardcoding values where possible. Explain in the comments how 
 you ensure consistency of inserted data, how relationships are preserved
*/

-- USERS
INSERT INTO users (username, email, password_hash, display_name, personal_info, location_info, created_at)
VALUES
    ('ali123', 'ali@gmail.com', 'Hash1', 'Ali', 'Student', 'Astana', TIMESTAMP '2026-03-15 10:00:00'),
    ('temirlan', 'temirlan@gmail.com', 'Hash2', 'Temirlan', 'Developer', 'Almaty', TIMESTAMP '2026-03-15 10:10:00'),
    ('dana_design', 'dana@gmail.com', 'Hash3', 'Dana', 'Designer', 'Astana', TIMESTAMP '2026-03-15 10:20:00')
ON CONFLICT DO NOTHING;

-- USER PROFILE HISTORY
INSERT INTO user_profile_history (user_id, display_name, personal_info, location_info, changed_at)
SELECT u.user_id, v.display_name, v.personal_info, v.location_info, v.changed_at
FROM (
    VALUES
        ('ali123', 'Ali', 'Student', 'Astana', TIMESTAMP '2026-03-17 15:38:01'),
        ('temirlan', 'Temir', 'Junior Developer', 'Almaty', TIMESTAMP '2026-03-18 10:00:00'),
        ('dana_design', 'Dana K.', 'Graphic Artist', 'Astana', TIMESTAMP '2026-03-18 11:00:00')
) AS v(username, display_name, personal_info, location_info, changed_at)
JOIN users u ON u.username = v.username
WHERE NOT EXISTS (
    SELECT 1
    FROM user_profile_history h
    WHERE h.user_id = u.user_id
      AND h.changed_at = v.changed_at
);

-- PRIVACY SETTING 
INSERT INTO privacy_setting (user_id, profile_visibility, post_visibility, updated_at)
SELECT u.user_id, v.profile_visibility, v.post_visibility, v.updated_at
FROM (
    VALUES
        ('ali123', 'public', 'public', TIMESTAMP '2026-03-19 12:00:00'),
        ('temirlan', 'private', 'private', TIMESTAMP '2026-03-19 12:05:00'),
        ('dana_design', 'followers_only', 'public', TIMESTAMP '2026-03-19 12:10:00')
) AS v(username, profile_visibility, post_visibility, updated_at)
JOIN users u ON u.username = v.username
ON CONFLICT (user_id) DO NOTHING;

-- PRIVACY SETTING HISTORY
INSERT INTO privacy_setting_history (user_id, profile_visibility, post_visibility, changed_at)
SELECT u.user_id, v.profile_visibility, v.post_visibility, v.changed_at
FROM (
    VALUES
        ('ali123', 'private', 'private', TIMESTAMP '2026-03-18 15:38:01'),
        ('temirlan', 'public', 'public', TIMESTAMP '2026-03-18 15:40:00'),
        ('dana_design', 'public', 'followers_only', TIMESTAMP '2026-03-18 15:45:00')
) AS v(username, profile_visibility, post_visibility, changed_at)
JOIN users u ON u.username = v.username
WHERE NOT EXISTS (
    SELECT 1
    FROM privacy_setting_history h
    WHERE h.user_id = u.user_id
      AND h.changed_at = v.changed_at
);

-- POSTS
INSERT INTO posts (user_id, body, visibility, posted_at)
SELECT u.user_id, v.body, v.visibility, v.posted_at
FROM (
    VALUES
        ('ali123', 'Here is the top workout of the day.', 'public', TIMESTAMP '2026-03-20 09:00:00'),
        ('temirlan', 'I want to say that data modeling matters.', 'private', TIMESTAMP '2026-03-20 09:05:00'),
        ('dana_design', NULL, 'followers_only', TIMESTAMP '2026-03-20 09:10:00')
) AS v(username, body, visibility, posted_at)
JOIN users u ON u.username = v.username
WHERE NOT EXISTS (
    SELECT 1
    FROM posts p
    WHERE p.user_id = u.user_id
      AND p.posted_at = v.posted_at
);

-- POST MEDIAS
INSERT INTO post_medias (post_id, media_type, url, added_at)
SELECT p.post_id, v.media_type, v.url, v.added_at
FROM (
    VALUES
        (TIMESTAMP '2026-03-20 09:00:00', 'image', 'https://example.com/workout.jpg', TIMESTAMP '2026-03-20 09:01:00'),
        (TIMESTAMP '2026-03-20 09:05:00', 'gif',   'https://example.com/modeling.gif', TIMESTAMP '2026-03-20 09:06:00'),
        (TIMESTAMP '2026-03-20 09:10:00', 'image', 'https://example.com/design.png', TIMESTAMP '2026-03-20 09:11:00')
) AS v(posted_at, media_type, url, added_at)
JOIN posts p ON p.posted_at = v.posted_at
WHERE NOT EXISTS (
    SELECT 1
    FROM post_medias pm
    WHERE pm.url = v.url
);

-- HASHTAGS
INSERT INTO hashtags (hashtag_name)
VALUES
    ('gym'),
    ('lifestyle'),
    ('coding')
ON CONFLICT DO NOTHING;

-- POST HASHTAGS
INSERT INTO post_hashtags (post_id, hashtag_id, tagged_at)
SELECT p.post_id, h.hashtag_id, v.tagged_at
FROM (
    VALUES
        (TIMESTAMP '2026-03-20 09:00:00', 'gym', TIMESTAMP '2026-03-20 09:02:00'),
        (TIMESTAMP '2026-03-20 09:05:00', 'coding', TIMESTAMP '2026-03-20 09:07:00'),
        (TIMESTAMP '2026-03-20 09:10:00', 'lifestyle', TIMESTAMP '2026-03-20 09:12:00')
) AS v(posted_at, hashtag_name, tagged_at)
JOIN posts p ON p.posted_at = v.posted_at
JOIN hashtags h ON h.hashtag_name = v.hashtag_name
ON CONFLICT (post_id, hashtag_id) DO NOTHING;

-- LIKES
INSERT INTO likes (post_id, user_id, liked_at)
SELECT p.post_id, u.user_id, v.liked_at
FROM (
    VALUES
        ('ali123', TIMESTAMP '2026-03-20 09:05:00', TIMESTAMP '2026-03-20 10:00:00'),
        ('temirlan', TIMESTAMP '2026-03-20 09:00:00', TIMESTAMP '2026-03-20 10:01:00'),
        ('dana_design', TIMESTAMP '2026-03-20 09:00:00', TIMESTAMP '2026-03-20 10:02:00')
) AS v(username, post_posted_at, liked_at)
JOIN users u ON u.username = v.username
JOIN posts p ON p.posted_at = v.post_posted_at
ON CONFLICT (user_id, post_id) DO NOTHING;

-- COMMENTS root 
INSERT INTO comments (post_id, user_id, parent_comment_id, body, commented_at)
SELECT p.post_id, u.user_id, NULL, v.body, v.commented_at
FROM (
    VALUES
        ('dana_design', TIMESTAMP '2026-03-20 09:00:00', 'Looks great!', TIMESTAMP '2026-03-20 10:05:00'),
        ('ali123', TIMESTAMP '2026-03-20 09:05:00', 'Nice point about modeling.', TIMESTAMP '2026-03-20 10:06:00')
) AS v(username, post_posted_at, body, commented_at)
JOIN users u ON u.username = v.username
JOIN posts p ON p.posted_at = v.post_posted_at
WHERE NOT EXISTS (
    SELECT 1
    FROM comments c
    WHERE c.user_id = u.user_id
      AND c.post_id = p.post_id
      AND c.body = v.body
      AND c.commented_at = v.commented_at
);

-- COMMENTS reply 
INSERT INTO comments (post_id, user_id, parent_comment_id, body, commented_at)
SELECT p.post_id,
       u.user_id,
       parent.comment_id,
       'Thanks!',
       TIMESTAMP '2026-03-20 10:07:00'
FROM users u
JOIN posts p
  ON p.posted_at = TIMESTAMP '2026-03-20 09:00:00'
JOIN comments parent
  ON parent.post_id = p.post_id
 AND parent.body = 'Looks great!'
 AND parent.commented_at = TIMESTAMP '2026-03-20 10:05:00'
WHERE u.username = 'ali123'
  AND NOT EXISTS (
      SELECT 1
      FROM comments c
      WHERE c.user_id = u.user_id
        AND c.post_id = p.post_id
        AND c.body = 'Thanks!'
        AND c.commented_at = TIMESTAMP '2026-03-20 10:07:00'
  );

-- FOLLOWS
INSERT INTO follows (follower_id, followee_id, followed_at)
SELECT follower.user_id, followee.user_id, v.followed_at
FROM (
    VALUES
        ('ali123', 'temirlan', TIMESTAMP '2026-03-20 11:00:00'),
        ('temirlan', 'dana_design', TIMESTAMP '2026-03-20 11:01:00'),
        ('dana_design', 'ali123', TIMESTAMP '2026-03-20 11:02:00')
) AS v(follower_username, followee_username, followed_at)
JOIN users follower ON follower.username = v.follower_username
JOIN users followee ON followee.username = v.followee_username
ON CONFLICT (follower_id, followee_id) DO NOTHING;

-- SHARES
INSERT INTO shares (post_id, user_id, shared_note, shared_at)
SELECT p.post_id, u.user_id, v.shared_note, v.shared_at
FROM (
    VALUES
        ('ali123', TIMESTAMP '2026-03-20 09:05:00', 'Look at this insight.', TIMESTAMP '2026-03-20 12:00:00'),
        ('temirlan', TIMESTAMP '2026-03-20 09:00:00', 'Useful example.', TIMESTAMP '2026-03-20 12:01:00'),
        ('dana_design', TIMESTAMP '2026-03-20 09:00:00', 'Great inspiration.', TIMESTAMP '2026-03-20 12:02:00')
) AS v(username, post_posted_at, shared_note, shared_at)
JOIN users u ON u.username = v.username
JOIN posts p ON p.posted_at = v.post_posted_at
WHERE NOT EXISTS (
    SELECT 1
    FROM shares s
    WHERE s.user_id = u.user_id
      AND s.post_id = p.post_id
      AND s.shared_at = v.shared_at
);

/*
Add a not null 'record_ts' field to each table using ALTER TABLE 
statements, set the default value to current_date, and check to 
make sure the value has been set for the existing rows.
*/
ALTER TABLE users ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE user_profile_history ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE privacy_setting ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE privacy_setting_history ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE post_medias ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE hashtags ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE post_hashtags ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE likes ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE follows ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;
ALTER TABLE shares ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT CURRENT_DATE;

/*Ensuring existing rows are populated*/ 
UPDATE users SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE user_profile_history SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE privacy_setting SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE privacy_setting_history SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE posts SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE post_medias SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE hashtags SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE post_hashtags SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE likes SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE comments SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE follows SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;
UPDATE shares SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;

ALTER TABLE users ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE user_profile_history ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE privacy_setting ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE privacy_setting_history ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE posts ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE post_medias ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE hashtags ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE post_hashtags ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE likes ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE comments ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE follows ALTER COLUMN record_ts SET NOT NULL;
ALTER TABLE shares ALTER COLUMN record_ts SET NOT NULL;

COMMIT;

/*
Verification query
*/

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'users',
    'user_profile_history',
    'privacy_setting',
    'privacy_setting_history',
    'posts',
    'post_medias',
    'hashtags',
    'post_hashtags',
    'likes',
    'comments',
    'follows',
    'shares'
)
ORDER BY table_name;

/*
Question answers:

PHYSICAL MODEL COMMENTS
This database is for a social media platform. It follows the logical 
model and stays in 3NF.

DATA TYPES
I used BIGINT for ids because ids must be numeric, stable, and able to 
store many rows.
If I chose a wrong type like small INT, it could run out of space later.
I used VARCHAR for short text like username, email, visibility, media_type
, and hashtag_name.
If the type is wrong or too short, valid values may be cut or rejected.
I used TEXT for long values like post body, comment body, password_hash,
URL, and notes.
If I used a small VARCHAR, long text might not fit.
I used TIMESTAMP for action dates because I need both date and time.
If I used only DATE, I would lose the exact time of the action.

DEFAULT VALUES AND GENERATED COLUMNS
I used GENERATED ALWAYS AS IDENTITY for primary keys, so ids are created 
automatically.
I used DEFAULT CURRENT_TIMESTAMP for created/changed/posted dates, so 
time is added automatically.
I used DEFAULT CURRENT_DATE for record_ts.
I used DEFAULT 'public' for visibility fields where needed.

FOREIGN KEYS
Foreign keys connect related tables.
If a foreign key is missing, wrong data can appear.
For example, a like could point to a post that does not exist, 
or a comment could belong to a deleted user.
This would break data integrity and make reports incorrect.

WHY DDL ORDER IS IMPORTANT
I created parent tables first and child tables after that.
For example, users must exist before posts, and posts must exist before 
likes or comments.
If the order is wrong, we will get an error because the referenced table 
does not exist yet.

CONSTRAINTS
I used NOT NULL, UNIQUE, CHECK, PRIMARY KEY, and FOREIGN KEY constraints.
NOT NULL stops empty important values.
Without it, rows could have missing usernames, missing post authors, or 
missing post text where required.
UNIQUE stops duplicates.
For example, username and email must be unique.
CHECK constraints allow only correct values.
For example, visibility can only be 'public', 'private', or 
'followers_only'.
For dates, I used checks so inserted dates must be later than 
January 1, 2000.

WHY PRIMARY KEYS ARE IMPORTANT
Primary keys make each row unique.
Without a primary key, it would be hard to identify rows correctly and 
foreign keys could not work properly.

SAMPLE DATA AND CONSISTENCY
I inserted sample data in the correct order: parent rows first, child 
rows second.
I used ON CONFLICT DO NOTHING or WHERE NOT EXISTS so the script can be 
run again without duplicates.
This keeps the script reusable and rerunnable.

RECORD_TS
After creating and filling tables, I added record_ts to each table with 
ALTER TABLE.
It is NOT NULL and has DEFAULT CURRENT_DATE.
I also checked that old rows received this value correctly.
*/