# SQL INDEX Statement Inducer

This script takes a SQL structure dump (i.e. a sequence of `CREATE TABLE` commands), and translates them into a series of `DROP INDEX` and `ADD INDEX` statements. `ADD INDEX` statements against the same table are grouped within a single `ALTER TABLE` command, so you only rebuild a table once no matter how many indices it has.

## Why?

At Wistia, we've found this useful in two situations:

1. When importing large tables from one database to another, we can transfer the data faster if the target database does not need to build all the indices as the data arrive. We achieve this by dropping all the indices on the target database before the import, and then rebuilding them when the import is complete. This may increase the total time to get the target database up to a production spec, but it minimizes the time needed to ingest the data. This is critically important if we have a narrow time window to work with. For example, when creating a replica while splitting a shard, we need to ensure our import takes less time than our replication logs are persisted for.
2. Amazon's Database Migration Service does not support importing of secondary indices. When moving a database to the AWS Relational Database Service, we need to recreate our indices after the import.

This tool provides commands you can cut and paste (we recommend proofreading, though!) into a SQL prompt to drop and regenerate all of your indices.

## How?

1. Dump your SQL schema to a .sql file.
2. Run `ruby ./generate_index_statements.rb <your sql schema file>`

## Example

Consider a very basic photo sharing app. Its schema may look like this:

``` sql
CREATE TABLE `accounts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `cname` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_users_on_name` (`name`),
  KEY `index_accounts_on_cname` (`cname`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `photos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) DEFAULT NULL,
  `hashed_id` varchar(40) DEFAULT NULL,
  `parent_id` int(11) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `filesize` bigint(20) DEFAULT NULL,
  `on_s3` tinyint(1) NOT NULL DEFAULT '0',
  `foreign_data` varchar(255) DEFAULT NULL,
  `foreign_id` varchar(255) DEFAULT NULL,
  `md5` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_photos_on_hashed_id` (`hashed_id`),
  KEY `index_photos_on_parent_id` (`parent_id`),
  KEY `index_photos_on_user_id_and_foreign_id` (`account_id`,`foreign_id`),
  KEY `index_photos_on_md5` (`md5`),
  KEY `index_photos_on_on_s3` (`on_s3`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `s3_uploads` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `photo_id` int(11) DEFAULT NULL,
  `failed_at` datetime DEFAULT NULL,
  `failure_message` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_s3_uploads_on_photo_id` (`photo_id`),
  KEY `index_s3_uploads_on_failed_at` (`failed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

To optimize for import speed, we'll want to:

1. Create this schema on our target
2. Drop the secondary indices
3. Import our data.
4. Recreate the secondary indices.

This tool facilitates steps 2 and 4. Run:

`ruby ./generate_index_statements.rb ./example/schema.sql`

and we get:

``` sql
DROP statements:

DROP INDEX `index_users_on_name` ON accounts;
DROP INDEX `index_accounts_on_cname` ON accounts;
DROP INDEX `index_photos_on_hashed_id` ON photos;
DROP INDEX `index_photos_on_parent_id` ON photos;
DROP INDEX `index_photos_on_user_id_and_foreign_id` ON photos;
DROP INDEX `index_photos_on_md5` ON photos;
DROP INDEX `index_photos_on_on_s3` ON photos;
DROP INDEX `index_s3_uploads_on_photo_id` ON s3_uploads;
DROP INDEX `index_s3_uploads_on_failed_at` ON s3_uploads;

CREATE statements:

ALTER TABLE accounts
ADD UNIQUE INDEX `index_users_on_name` (`name`),
ADD INDEX `index_accounts_on_cname` (`cname`);

ALTER TABLE photos
ADD UNIQUE INDEX `index_photos_on_hashed_id` (`hashed_id`),
ADD INDEX `index_photos_on_parent_id` (`parent_id`),
ADD INDEX `index_photos_on_user_id_and_foreign_id` (`account_id`,`foreign_id`),
ADD INDEX `index_photos_on_md5` (`md5`),
ADD INDEX `index_photos_on_on_s3` (`on_s3`);

ALTER TABLE s3_uploads
ADD UNIQUE INDEX `index_s3_uploads_on_photo_id` (`photo_id`),
ADD INDEX `index_s3_uploads_on_failed_at` (`failed_at`);
```

You can copy and paste to your SQL console the DROP statements for step 2, and the ALTER TABLE statements for step 4.

## Caution

If you have a large database, altering tables can take a very long time. Be sure to run those commands via screen or tmux so that your session isn't lost if you lose your SSH connection.

## Contributing and Testing

Contributions are welcome! Please run the tests to ensure you have not broken anything:

```
bundle install
bundle exec rspec spec
```
