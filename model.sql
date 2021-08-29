-- Schema for the mypics.net photo-sharing site
--
-- Written by Jittinun Trairattanasirikul (Nee)
--
-- Conventions:
-- * all entity table names are plural
-- * most entities have an artifical primary key called "id"
-- * foreign keys are named after the relationship they represent

/*
----------------------------
Assumptions: 
----------------------------
1. Application level to insert People (user) name as family- and given-names.
2. Application level to check portrait photo in JPEG and small than 64KB.
3. Application level to update freq tag (tag cloud). 
4. Contact_lists represents Friends lists which include friends, family and workmates
----------------------------
Verification:
------------------------------
1. PK in all tables
2. FK in all tables
3. Constraint: Domain, Default 
4. One Relationship (arrow) => UNIQUE
5. Total participation (thick line) => NOT NULL
------------------------------
Version History 
------------------------------
1.0: Basic schema
1.1: Change from Contact_Lists to Friends, 
	 Changed from Persons_Member_Contact_lists to People_Member_Friends
	 Changed from Photos.user_id to Photos.owned_by_user_id
1.2: Change from Friends to Contact_lists
	 Changed from People_Member_Friends to Persons_Member_Contact_lists
--------------------------------*/
-- Domains (you may add more)

create domain URLValue as
	varchar(100) check (value like 'https://%');

create domain EmailValue as
	varchar(100) check (value like '%@%.%');

create domain GenderValue as
	varchar(6) check (value in ('male','female'));

create domain GroupModeValue as
	varchar(15) check (value in ('private','by-invitation','by-request'));

create domain ContactListTypeValue as
	varchar(10) check (value in ('friends','family','workmates'));
	-- varchar(10) check (value in ('friends','family'));

create domain NameValue as varchar(50);

create domain LongNameValue as varchar(100);

---------------------
-- Custom domains
---------------------
create domain VisibilityValue as
	varchar(15) check (value in ('private','friends','friends+family','public'));
	
create domain SafetyLevelValue as
	varchar(15) check (value in ('safe','moderate','restricted'));
	
create domain RatingValue as
	integer check (value between 1 and 5); -- whole numbers, not decimal
	
create domain RankOrderValue as
	integer check (value between 1 and 32767); -- Small positive integer (Smallint max 32,767), excluding zero

create domain PositiveIntegerValue as
	integer check (value > 0); -- Positive integer value, greater than zero
	
create domain FileSizeKBValue as
	integer check (value >= 0);

---------------------------------
-- Tables (you must add more)
---------------------------------
create table People (
	id          	serial,
	given_names		NameValue	not null,
	family_name		NameValue,
	displayed_name	LongNameValue, -- Assumption: this can be done by application level to add the default given_names || family_name. 
	email_address	EmailValue not null, 
	primary key (id)
);

create table Discussions (
	id		serial,
	title	NameValue,
	primary key (id)
);
	
create table Photos (
	id					serial,
	title				NameValue,
	description			text, 
	date_taken			date,
	date_uploaded		date default CURRENT_DATE, -- To add current date by default if no value inserted.
	technical_details	text,
	safety_level		SafetyLevelValue,
	visibility			VisibilityValue,
	file_size			FileSizeKBValue, -- Domain: to check for a whole number of KB. File size can be 0 KB if less than KB.
	owner_user_id		integer	unique not null, -- Total participation
	discussion_id		integer unique, -- N:1 relationship
	primary key (id),
	-- foreign key (owner_user_id) references Users(person_id), -- To be added after create Users table
	foreign key (discussion_id) references Discussions(id)
);

create table Users (
	person_id			integer, 
	portrait_photo_id	integer unique, -- Assumption: Application to check portrait photo in JPEG and small than 64KB.
	website				URLValue,
	date_registered		date default CURRENT_DATE, -- Record the date when each user joins the site.
	gender				GenderValue,
	birthday			date, -- Per Ed's discussion, not required to check for user's age. This also can be done at application leve.
	password			NameValue not null,
	primary key (person_id),
	foreign key (person_id) references People(id),
	foreign key (portrait_photo_id) references Photos(id)
);

-- Add FK to Photos table
alter table Photos add constraint FK_Photos_Users foreign key (owner_user_id) references Users(person_id);


create table Groups (
	id				serial,
	title			text, 
	mode			GroupModeValue,
	owner_user_id	integer unique not null, -- Total participation, the owner is automatically a member.
	primary key (id),
	foreign key (owner_user_id) references Users(person_id)
);

create table Users_Member_Groups (
	user_id		integer,
	group_id	integer not null, -- Total participation
	primary key (user_id, group_id),
	foreign key (user_id) references Users(person_id),
	foreign key (group_id) references Groups(id)
);

-- Contact_lists (represents Friends or Friend_Lists)
create table Contact_lists (
	id				serial,
	title			ContactListTypeValue,
	owner_user_id	integer unique not null, -- Total participation
	primary key (id),
	foreign key (owner_user_id) references Users(person_id)
);

create table People_Member_Contact_lists (
	person_id		integer,
	friend_id		integer	not null, -- Total participation
	primary key (person_id, friend_id),
	foreign key (person_id) references People(id),
	foreign key (friend_id) references Contact_lists(id)
);
-- Tags
create table Tags (
	id		serial,
	name	NameValue,
	freq	PositiveIntegerValue, --* See an assumption below
	primary key(id)
);
/* 
* Per Ed's discussion https://edstem.org/courses/3591/discussion/174964
To update freq should be done via application level.
*/

create table Photos_Has_Tags (
	tag_id			integer	not null, -- Total participation
	photo_id		integer,
	user_id			integer,
	when_tagged	timestamp default NOW()::timestamp, -- Current timestamp without timezone
	primary key (tag_id, photo_id, user_id),
	foreign key (tag_id) references Tags(id),
	foreign key (photo_id) references Photos(id),
	foreign key (user_id) references Users(person_id)
);
-- Rating
create table Users_Rates_Photos (
	user_id			integer,
	photo_id		integer,
	when_rated		timestamp default NOW()::timestamp, -- Current timestamp without timezone
	rating			RatingValue, -- Domain: 1..5 whole numbers
	primary key (user_id, photo_id),
	foreign key (user_id) references Users(person_id),
	foreign key (photo_id) references Photos(id)
);

-- Collection - a group of photos
create table Collections (
	id				serial,
	title			NameValue,
	description		text, -- Arbitrary text description is text data type.
	key_photo_id	integer unique not null, -- Total participation
	primary key (id),
	foreign key (key_photo_id) references Photos(id)
);
-- Rank Order
create table Photos_in_Collections (
	photo_id		integer,
	collection_id	integer,
	rank_order		RankOrderValue, -- Domain to check for small positive integer.
	primary key (photo_id, collection_id),
	foreign key (photo_id) references Photos(id),
	foreign key (collection_id) references Collections(id)
);

create table User_Collections (
	collection_id	integer,
	owner_user_id	integer unique not null, -- Total participation
	primary key (collection_id),
	foreign key (collection_id) references Collections(id),
	foreign key (owner_user_id) references Users(person_id)
);

create table Group_Collections (
	collection_id	integer,
	owner_group_id	integer unique not null, -- Total participation
	primary key (collection_id),
	foreign key (collection_id) references Collections(id),
	foreign key (owner_group_id) references Groups(id)
);

-- Comments
create table Comments (
	id					serial,
	when_posted			timestamp	default NOW()::timestamp, -- Current timestamp without timezone
	content				text, -- arbitrary text string
	discussion_id		integer unique not null, -- Total participation
	author_user_id		integer unique not null, -- Total participation
	reply_to_comment_id	integer unique, 
	primary key (id),
	foreign key (discussion_id) references Discussions(id),
	foreign key (author_user_id) references Users(person_id),
	foreign key (reply_to_comment_id) references Comments(id) -- Specs: Comments: a comment may be a reply to some other comment
);

-- Group Discussion
create table Discussions_Has_Groups (
	discussion_id		integer,
	group_id			integer,
	primary key (discussion_id, group_id),
	foreign key (discussion_id) references Discussions(id),
	foreign key (group_id) references Groups(id)
);