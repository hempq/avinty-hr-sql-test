-- hospital_user
create table hospital_user
(
    id          serial primary key,
    email       varchar(256) not null
        constraint hospital_user_unique_email_constraint unique,
    password    varchar(128) not null,
    first_name  varchar(128),
    last_name   varchar(128),
    birth_date  timestamp,
    phone       varchar(16),
    created_by  integer references hospital_user (id),
    created_on  timestamp    not null,
    modified_by integer references hospital_user (id),
    modified_on timestamp    not null
);

-- codestore type
create table code_store_type
(
    id          serial primary key,
    name        varchar(128) not null
        constraint code_store_type_unique_name_constraint unique,
    created_by  integer      not null references hospital_user (id),
    created_on  timestamp    not null,
    modified_by integer      not null references hospital_user (id),
    modified_on timestamp    not null
);

-- codestore item
create table code_store_item
(
    id                 serial primary key,
    code_store_type_id integer      not null references code_store_type (id),
    name               varchar(128) not null
        constraint code_store_item_unique_name_constraint unique,
    created_by         integer      not null references hospital_user (id),
    created_on         timestamp    not null,
    modified_by        integer      not null references hospital_user (id),
    modified_on        timestamp    not null
);

-- country
create table country
(
    id   serial primary key,
    name varchar(255)
);

-- county
create table county
(
    id   serial primary key,
    name varchar(255)
);

-- city
create table city
(
    id         serial primary key,
    zip        varchar(255),
    name       varchar(255),
    country_id integer not null references country (id),
    county_id  integer not null references county (id)
);

-- address
create table address
(
    id            serial primary key,
    city          integer   not null references city (id),
    street        varchar(255),
    street_number varchar(50),
    created_by    integer   not null references hospital_user (id),
    created_on    timestamp not null,
    modified_by   integer   not null references hospital_user (id),
    modified_on   timestamp not null

);


-- patient table
create table patient
(
    id             serial primary key,
    email          varchar(255) not null
        constraint patient_unique_email_constraint unique,
    first_name     varchar(255),
    last_name      varchar(255),
    mothers_name   varchar(255),
    phone_number   varchar(255),
    gender         integer      not null references code_store_item (id),
    date_of_birth  timestamp    not null,
    date_of_death  timestamp,
    place_of_birth integer      not null references city (id),
    address_id     integer references address (id),
    created_by     integer      not null references hospital_user (id),
    created_on     timestamp    not null,
    modified_by    integer      not null references hospital_user (id),
    modified_on    timestamp    not null
);

create type proximity_type as enum ('1', '2', '3', '4', '5', '6', '7', '8', '9', '10');

-- relationship table
create table relationship
(
    id          serial primary key,
    type        integer references code_store_item (id),
    quality     integer references code_store_item (id),
    proximity   proximity_type,
    start_date  timestamp not null,
    end_date    timestamp,
    created_by  integer   not null references hospital_user (id),
    created_on  timestamp not null,
    modified_by integer   not null references hospital_user (id),
    modified_on timestamp not null
);


-- patient_x_patient_x_relationship table
create table patient_x_patient_x_relationship
(
    patient1_id     integer not null references patient (id),
    patient2_id     integer not null references patient (id),
    relationship_id integer not null references relationship (id)
);

create function trigger_start_date() returns trigger
    language plpgsql
as
$$
declare
    patient1_date_of_birth timestamp;
    patient2_date_of_birth timestamp;
    start_date_var         timestamp;
begin
    select date_of_birth into patient1_date_of_birth from patient where id = new.patient1_id;
    select date_of_birth into patient2_date_of_birth from patient where id = new.patient2_id;
    select start_date into start_date_var from relationship where new.relationship_id = id;

    if (start_date_var < patient1_date_of_birth) or (start_date_var < patient2_date_of_birth) then
        if patient1_date_of_birth < patient2_date_of_birth then
            update relationship set start_date = patient1_date_of_birth where id = new.relationship_id;
        else
            update relationship set start_date = patient2_date_of_birth where id = new.relationship_id;
        end if;
    end if;
    return new;
end;
$$;

create trigger set_start_date_in_relationship
    before insert
    on patient_x_patient_x_relationship
    for each row
execute procedure trigger_start_date();

create function trigger_end_date() returns trigger
    language plpgsql
as
$$
declare
    r integer;
begin
    for r in
        select relationship_id from patient_x_patient_x_relationship where patient1_id = new.id or patient2_id = new.id
        loop
            if (select end_date from relationship where id = r) > new.date_of_death then
                update relationship set end_date = new.date_of_death where id = r;
            end if;
        end loop;
    return new;
end;
$$;

create trigger set_end_date_in_relationship
    after update
    on patient
    for each row
execute procedure trigger_end_date();
