-- CNrecipe API v1. Compatible with PostgreSQL 17+ and Supabase Auth.
-- Client roles cannot edit catalog content. User writes are owner scoped.
create schema if not exists cnrecipe_private;
revoke all on schema cnrecipe_private from public;
grant usage on schema cnrecipe_private to anon, authenticated;

create table public.cnrecipe_ingredients (
 id text primary key check (id ~ '^[a-z0-9-]{1,100}$'),
 name text not null check (length(name) between 1 and 100)
);
create table public.cnrecipe_recipes (
 id text primary key check (id ~ '^[a-z0-9-]{1,100}$'),
 current_version integer not null check (current_version > 0),
 active boolean not null default true,
 display_order integer not null default 0
);
create table public.cnrecipe_versions (
 recipe_id text not null references public.cnrecipe_recipes(id),
 version integer not null check (version > 0),
 document jsonb not null check (
  jsonb_typeof(document)='object' and document->>'id'=recipe_id
  and (document->>'version')::integer=version
  and jsonb_array_length(document->'ingredients') between 1 and 100
  and jsonb_array_length(document->'steps') between 1 and 100
 ),
 created_at timestamptz not null default now(),
 primary key(recipe_id,version)
);
alter table public.cnrecipe_recipes add constraint cnrecipe_current_version
 foreign key(id,current_version) references public.cnrecipe_versions(recipe_id,version)
 deferrable initially deferred;
create index cnrecipe_current_version_lookup on public.cnrecipe_recipes(id,current_version);

create function cnrecipe_private.immutable_version() returns trigger
language plpgsql set search_path=pg_catalog as $$
begin raise exception 'Published recipe versions are immutable; create a new version'; end;
$$;
create trigger cnrecipe_immutable_version before update or delete on public.cnrecipe_versions
 for each row execute function cnrecipe_private.immutable_version();

alter table public.cnrecipe_ingredients enable row level security;
alter table public.cnrecipe_recipes enable row level security;
alter table public.cnrecipe_versions enable row level security;
create policy catalog_ingredients_read on public.cnrecipe_ingredients for select to anon,authenticated using(true);
create policy catalog_recipes_read on public.cnrecipe_recipes for select to anon,authenticated using(active);
create policy catalog_versions_read on public.cnrecipe_versions for select to anon,authenticated
 using(exists(select 1 from public.cnrecipe_recipes r where r.id=recipe_id and r.active));
revoke all on public.cnrecipe_ingredients,public.cnrecipe_recipes,public.cnrecipe_versions from anon,authenticated;
grant select on public.cnrecipe_ingredients,public.cnrecipe_recipes,public.cnrecipe_versions to anon,authenticated;

create function cnrecipe_private.quote_document(d jsonb, servings integer, units text) returns jsonb
language plpgsql immutable set search_path=pg_catalog as $$
declare items jsonb; factor numeric;
begin
 if servings is null or units is null or servings not between 1 and 8 or units not in ('US','Metric') then
  raise exception 'Choose 1 to 8 servings and US or Metric units' using errcode='22023';
 end if;
 factor:=servings/(d->>'baseServings')::numeric;
 if d->>'scalingMode'='wholeBatch' then factor:=ceil(factor); end if;
 select jsonb_agg(jsonb_build_object(
  'id',i->>'id','ingredientId',i->>'ingredientId','name',i->>'name',
  'quantity',q,'unit',u,
  'display',case i->>'quantityMode' when 'toTaste' then 'To taste' when 'asNeeded' then 'As needed'
    else trim_scale(q)::text||' '||u end
 ) order by n) into items from (
  select i,n,coalesce(i->>case when units='US' then 'usUnit' else 'metricUnit' end,'') as u,
   case when i->>'quantityMode' in ('toTaste','asNeeded') then 0::numeric
    when round((i->>case when units='US' then 'usQuantity' else 'metricQuantity' end)::numeric*factor,2)=0
     then round((i->>case when units='US' then 'usQuantity' else 'metricQuantity' end)::numeric*factor,4)
    else round((i->>case when units='US' then 'usQuantity' else 'metricQuantity' end)::numeric*factor,2) end as q
  from jsonb_array_elements(d->'ingredients') with ordinality a(i,n)
 ) measured;
 return jsonb_build_object('recipeId',d->>'id','recipeVersion',(d->>'version')::integer,
  'servings',servings,'units',units,'ingredients',items);
end;
$$;

create function public.cnrecipe_recipe(p_id text,p_version integer default null) returns jsonb
language plpgsql stable set search_path=pg_catalog as $$
declare d jsonb; quotes jsonb;
begin
 select v.document into d from public.cnrecipe_versions v join public.cnrecipe_recipes r on r.id=v.recipe_id
 where r.id=p_id and v.version=coalesce(p_version,r.current_version) and r.active;
 if d is null then raise exception 'Recipe not found' using errcode='P0002'; end if;
 select jsonb_agg(cnrecipe_private.quote_document(d,n,u) order by n,u) into quotes
 from generate_series(1,8) n cross join (values('US'),('Metric')) units(u);
 return d||jsonb_build_object('quotes',quotes);
end;
$$;

-- User entities preserve tombstones. A server sequence supplies sync cursors.
create sequence public.cnrecipe_revision_seq;
create table public.cnrecipe_user_entities (
 owner_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('inventory','shopping','favorite','record','preferences')),
 id text not null check(id ~ '^[A-Za-z0-9_-]{1,160}$'),
 data jsonb not null check(jsonb_typeof(data)='object'),
 revision bigint not null default nextval('public.cnrecipe_revision_seq'),
 deleted boolean not null default false,
 updated_at timestamptz not null default now(),
 primary key(owner_id,kind,id)
);
create index cnrecipe_user_changes on public.cnrecipe_user_entities(owner_id,revision);
create table public.cnrecipe_mutations (
 owner_id uuid not null references auth.users(id) on delete cascade,
 id uuid not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(owner_id,id)
);
alter table public.cnrecipe_user_entities enable row level security;
alter table public.cnrecipe_mutations enable row level security;
create policy entities_owned_read on public.cnrecipe_user_entities for select to authenticated using((select auth.uid())=owner_id);
create policy entities_owned_insert on public.cnrecipe_user_entities for insert to authenticated with check((select auth.uid())=owner_id);
create policy entities_owned_update on public.cnrecipe_user_entities for update to authenticated
 using((select auth.uid())=owner_id) with check((select auth.uid())=owner_id);
create policy mutations_owned_read on public.cnrecipe_mutations for select to authenticated using((select auth.uid())=owner_id);
create policy mutations_owned_insert on public.cnrecipe_mutations for insert to authenticated with check((select auth.uid())=owner_id);
revoke all on public.cnrecipe_user_entities,public.cnrecipe_mutations from anon,authenticated;
grant select,insert,update on public.cnrecipe_user_entities to authenticated;
grant select,insert on public.cnrecipe_mutations to authenticated;
grant usage on sequence public.cnrecipe_revision_seq to authenticated;

create function cnrecipe_private.entity_json(e public.cnrecipe_user_entities) returns jsonb
language sql stable set search_path=pg_catalog as $$
 select jsonb_build_object('kind',e.kind,'id',e.id,'data',e.data,'revision',e.revision,'deleted',e.deleted);
$$;

create function cnrecipe_private.validate_entity(k text,d jsonb,today date) returns void
language plpgsql stable set search_path=pg_catalog as $$
begin
 if jsonb_typeof(d)<>'object' then raise exception 'Expected an object'; end if;
 case k
 when 'inventory' then
  if nullif(trim(d->>'name'),'') is null or length(d->>'name')>70 then raise exception 'Enter an ingredient name (up to 70 characters)'; end if;
  if d->>'group' is null or d->>'group' not in ('Produce','Meat & Protein','Dairy & Eggs','Sauces & Pantry') then raise exception 'Choose a valid category'; end if;
  if d->>'storage' is null or d->>'storage' not in ('Fridge','Freezer','Pantry') then raise exception 'Choose a storage location'; end if;
  if d->>'type' is null or d->>'type' not in ('Best before','Use by','Review on') then raise exception 'Choose a date label'; end if;
  if coalesce(d->>'added','') !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'Choose the added date'; end if;
  if (d->>'added')::date>today then raise exception 'Added date cannot be in the future'; end if;
  if coalesce(d->>'until','')<>'' and ((d->>'until') !~ '^\d{4}-\d{2}-\d{2}$' or (d->>'until')::date<(d->>'added')::date) then raise exception 'The tracked date cannot be earlier than the added date'; end if;
  if jsonb_typeof(d->'qty') is distinct from 'string' or length(d->>'qty')>35 then raise exception 'Enter a quantity (up to 35 characters)'; end if;
 when 'shopping' then
  if nullif(trim(d->>'name'),'') is null or length(d->>'name')>80 or jsonb_typeof(d->'checked') is distinct from 'boolean' then raise exception 'Enter an item name and purchase state'; end if;
 when 'favorite' then
  if not exists(select 1 from public.cnrecipe_recipes where id=d->>'recipeId') then raise exception 'Recipe not found'; end if;
 when 'record' then
  if jsonb_typeof(d->'rating') is distinct from 'number' or (d->>'rating')::integer not between 0 and 5 or (d->>'rating')::numeric<>floor((d->>'rating')::numeric) then raise exception 'Rating must be 0 to 5'; end if;
  if jsonb_typeof(d->'note') is distinct from 'string' or jsonb_typeof(d->'completedAt') is distinct from 'string' then raise exception 'Record needs a note and completion time'; end if;
  perform (d->>'completedAt')::timestamptz;
  if not exists(select 1 from public.cnrecipe_versions where recipe_id=d->>'recipeId' and version=(d->>'recipeVersion')::integer) then raise exception 'Recipe version not found'; end if;
 when 'preferences' then
  if d->>'units' is null or d->>'units' not in ('US','Metric') or d->>'region' is null or d->>'region' not in ('United States','United Kingdom','Canada','Australia') then raise exception 'Choose valid units and region'; end if;
  if jsonb_typeof(d->'largeText') is distinct from 'boolean' or jsonb_typeof(d->'allergens') is distinct from 'array' then raise exception 'Invalid preferences'; end if;
  if exists(select 1 from jsonb_array_elements_text(d->'allergens') a where a not in ('Peanuts','Soy','Wheat','Eggs','Sesame')) then raise exception 'Unknown allergen preference'; end if;
 else raise exception 'Unknown entity kind';
 end case;
 if nullif(d->>'ingredientId','') is not null and not exists(select 1 from public.cnrecipe_ingredients where id=d->>'ingredientId') then raise exception 'Ingredient ID not found'; end if;
end;
$$;

-- The trigger also protects direct Data API writes, rather than trusting RPC callers.
create function cnrecipe_private.guard_entity() returns trigger
language plpgsql set search_path=pg_catalog as $$
begin
 if tg_op='UPDATE' and (new.owner_id,new.kind,new.id) is distinct from (old.owner_id,old.kind,old.id) then raise exception 'Entity identity is immutable'; end if;
 perform pg_advisory_xact_lock(hashtextextended(coalesce(auth.uid(),new.owner_id)::text,0));
 if not new.deleted then perform cnrecipe_private.validate_entity(new.kind,new.data,(now() at time zone 'Pacific/Kiritimati')::date); end if;
 if new.kind='record' and not new.deleted then
  if tg_op='UPDATE' and not old.deleted then raise exception 'Cooking records are immutable'; end if;
  new.data:=new.data||jsonb_build_object('recipeSnapshot',public.cnrecipe_recipe(new.data->>'recipeId',(new.data->>'recipeVersion')::integer));
 end if;
 new.revision:=nextval('public.cnrecipe_revision_seq');new.updated_at:=now();return new;
end;
$$;
create trigger cnrecipe_user_entity_write before insert or update on public.cnrecipe_user_entities
 for each row execute function cnrecipe_private.guard_entity();

create function public.cnrecipe_catalog(p_query text default '',p_filter text default 'All',p_pantry jsonb default '[]',p_allergens jsonb default '[]') returns jsonb
language plpgsql stable set search_path=pg_catalog as $$
declare result jsonb; pantry jsonb:=p_pantry;
begin
 if length(p_query)>180 or p_filter not in ('All','Quick','Beginner','Vegetarian','Noodles','Pantry') or jsonb_typeof(p_pantry)<>'array' or jsonb_typeof(p_allergens)<>'array' then raise exception 'Invalid search' using errcode='22023'; end if;
 if jsonb_array_length(p_pantry)>500 or jsonb_array_length(p_allergens)>5 then raise exception 'Too many search inputs'; end if;
 if auth.uid() is not null and p_filter='Pantry' then
  select coalesce(jsonb_agg(data->>'name'),'[]'::jsonb) into pantry from public.cnrecipe_user_entities where owner_id=auth.uid() and kind='inventory' and not deleted;
 end if;
 select coalesce(jsonb_agg(public.cnrecipe_recipe(r.id)||jsonb_build_object('allergyAlerts',
  (select coalesce(jsonb_agg(a),'[]') from jsonb_array_elements_text(v.document->'allergens') a where p_allergens ? split_part(a,' ',1))
 ) order by r.display_order,r.id),'[]') into result
 from public.cnrecipe_recipes r join public.cnrecipe_versions v on v.recipe_id=r.id and v.version=r.current_version
 where r.active and (trim(p_query)='' or strpos(lower(v.document->>'name'||' '||(v.document->>'chineseName')||' '||(v.document->>'category')||' '||(select string_agg(i->>'name',' ') from jsonb_array_elements(v.document->'ingredients') i)),lower(trim(p_query)))>0)
 and case p_filter when 'Quick' then (v.document->>'minutes')::integer<=15
  when 'Beginner' then v.document->>'difficulty'='Beginner'
  when 'Vegetarian' then (v.document->>'vegetarian')::boolean
  when 'Noodles' then v.document->>'category'='Rice & Noodles'
  when 'Pantry' then exists(select 1 from jsonb_array_elements(v.document->'ingredients') i cross join jsonb_array_elements_text(pantry) p where p=i->>'ingredientId' or lower(trim(p))=lower(trim(i->>'name')))
  else true end;
 return jsonb_build_object('schemaVersion',1,'recipes',result,'catalogVersion',
  (select md5(string_agg(id||':'||current_version,',' order by id)) from public.cnrecipe_recipes where active));
end;
$$;

create function cnrecipe_private.merge_shopping(d jsonb) returns jsonb
language plpgsql set search_path=pg_catalog as $$
declare e public.cnrecipe_user_entities; target text;
begin
 perform cnrecipe_private.validate_entity('shopping',d,current_date);
 select * into e from public.cnrecipe_user_entities where owner_id=auth.uid() and kind='shopping' and not deleted
  and (nullif(d->>'ingredientId','') is not null and data->>'ingredientId'=d->>'ingredientId' or lower(trim(data->>'name'))=lower(trim(d->>'name'))) order by revision limit 1 for update;
 if found then return cnrecipe_private.entity_json(e); end if;
 target:=case when nullif(d->>'ingredientId','') is not null then 'ingredient-'||(d->>'ingredientId') else 'manual-'||md5(lower(trim(d->>'name'))) end;
 insert into public.cnrecipe_user_entities(owner_id,kind,id,data) values(auth.uid(),'shopping',target,d)
 on conflict(owner_id,kind,id) do update set data=excluded.data,deleted=false returning * into e;
 return cnrecipe_private.entity_json(e);
end;
$$;

create function public.cnrecipe_sync(p_cursor bigint default 0,p_operations jsonb default '[]',p_timezone text default 'UTC') returns jsonb
language plpgsql set search_path=pg_catalog as $$
declare op jsonb; op_id uuid; old_result jsonb; receipt jsonb; receipts jsonb:='[]'; entities jsonb; d jsonb;
 e public.cnrecipe_user_entities; k text; target text; action text; base bigint; dependency jsonb; dep_entity jsonb; items jsonb; item jsonb; today date; cursor_value bigint;
begin
 if auth.uid() is null then raise exception 'Sign in to sync' using errcode='28000'; end if;
 if jsonb_typeof(p_operations)<>'array' or jsonb_array_length(p_operations)>100 or p_cursor<0 then raise exception 'Invalid sync batch'; end if;
 if not exists(select 1 from pg_timezone_names where name=p_timezone) then raise exception 'Invalid timezone'; end if;
 today:=(now() at time zone p_timezone)::date;
 -- Serialize this user's batches, including concurrent retries on two devices.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 for op in select value from jsonb_array_elements(p_operations) loop
  op_id:=(op->>'id')::uuid;
  select result into old_result from public.cnrecipe_mutations where owner_id=auth.uid() and id=op_id;
  if found then receipts:=receipts||jsonb_build_array(old_result||jsonb_build_object('duplicate',true));continue; end if;
  begin
   k:=op->>'kind';target:=op->>'entityId';action:=op->>'action';base:=coalesce((op->>'baseRevision')::bigint,0);d:=op->'data';entities:='[]';
   if k is null or k not in ('inventory','shopping','favorite','record','preferences') or target is null or target !~ '^[A-Za-z0-9_-]{1,160}$' or action is null or action not in ('put','delete','shopping.add','shopping.recipe') then raise exception 'Invalid operation'; end if;
   if nullif(op->>'dependsOn','') is not null then
    select result into dependency from public.cnrecipe_mutations where owner_id=auth.uid() and id=(op->>'dependsOn')::uuid;
    if dependency is null or dependency->>'status'<>'applied' then raise exception 'An earlier edit needs review'; end if;
    select value into dep_entity from jsonb_array_elements(dependency->'entities') where value->>'kind'=k and value->>'id'=target;
    if dep_entity is null and jsonb_array_length(dependency->'entities')=1 then dep_entity:=dependency->'entities'->0; end if;
    if dep_entity is null or dep_entity->>'kind'<>k then raise exception 'Invalid dependency'; end if;
    target:=dep_entity->>'id';base:=(dep_entity->>'revision')::bigint;
   end if;
   if action='shopping.add' then
    if k<>'shopping' then raise exception 'Invalid shopping operation'; end if;
    entities:=jsonb_build_array(cnrecipe_private.merge_shopping(d));
   elsif action='shopping.recipe' then
    if k<>'shopping' then raise exception 'Invalid shopping operation'; end if;
    items:=cnrecipe_private.quote_document(public.cnrecipe_recipe(d->>'recipeId',(d->>'recipeVersion')::integer),(d->>'servings')::integer,d->>'units')->'ingredients';
    for item in select value from jsonb_array_elements(items) loop
     if d->'ingredientIds' is null or d->'ingredientIds' ? (item->>'ingredientId') then
      entities:=entities||jsonb_build_array(cnrecipe_private.merge_shopping(jsonb_build_object('name',item->>'name','ingredientId',item->>'ingredientId','qty',item->>'display','checked',false)));
     end if;
    end loop;
   else
    select * into e from public.cnrecipe_user_entities where owner_id=auth.uid() and kind=k and id=target for update;
    if coalesce(e.revision,0)<>base then
     receipt:=jsonb_build_object('id',op_id,'status','conflict','message','This item changed on another device','entities',case when e.id is null then '[]'::jsonb else jsonb_build_array(cnrecipe_private.entity_json(e)) end);
     insert into public.cnrecipe_mutations(owner_id,id,result) values(auth.uid(),op_id,receipt);receipts:=receipts||jsonb_build_array(receipt);continue;
    end if;
    if action='put' then
     perform cnrecipe_private.validate_entity(k,d,today);
     if k='record' then
      if e.id is not null and not e.deleted then raise exception 'Cooking records are immutable'; end if;
      d:=d||jsonb_build_object('recipeSnapshot',public.cnrecipe_recipe(d->>'recipeId',(d->>'recipeVersion')::integer));
     end if;
     insert into public.cnrecipe_user_entities(owner_id,kind,id,data) values(auth.uid(),k,target,d)
      on conflict(owner_id,kind,id) do update set data=excluded.data,deleted=false returning * into e;
    else
     insert into public.cnrecipe_user_entities(owner_id,kind,id,data,deleted) values(auth.uid(),k,target,coalesce(e.data,'{}'::jsonb),true)
      on conflict(owner_id,kind,id) do update set deleted=true returning * into e;
    end if;
    entities:=jsonb_build_array(cnrecipe_private.entity_json(e));
   end if;
   receipt:=jsonb_build_object('id',op_id,'status','applied','entities',entities);
  exception when others then
   receipt:=jsonb_build_object('id',op_id,'status','rejected','message',sqlerrm,'entities','[]'::jsonb);
  end;
  insert into public.cnrecipe_mutations(owner_id,id,result) values(auth.uid(),op_id,receipt);
  receipts:=receipts||jsonb_build_array(receipt);
 end loop;
 select coalesce(max(revision),0) into cursor_value from public.cnrecipe_user_entities where owner_id=auth.uid();
 select coalesce(jsonb_agg(cnrecipe_private.entity_json(changed) order by changed.revision),'[]') into entities from public.cnrecipe_user_entities changed where changed.owner_id=auth.uid() and changed.revision>p_cursor;
 return jsonb_build_object('cursor',cursor_value,'entities',entities,'receipts',receipts);
end;
$$;

revoke execute on all functions in schema cnrecipe_private from public;
grant execute on all functions in schema cnrecipe_private to anon,authenticated;
revoke execute on function public.cnrecipe_recipe(text,integer),public.cnrecipe_catalog(text,text,jsonb,jsonb),public.cnrecipe_sync(bigint,jsonb,text) from public;
grant execute on function public.cnrecipe_recipe(text,integer),public.cnrecipe_catalog(text,text,jsonb,jsonb) to anon,authenticated;
grant execute on function public.cnrecipe_sync(bigint,jsonb,text) to authenticated;
