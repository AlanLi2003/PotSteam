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
declare items jsonb;
begin
 if servings not between 1 and 8 or units not in ('US','Metric') then
  raise exception 'Choose 1 to 8 servings and US or Metric units' using errcode='22023';
 end if;
 select jsonb_agg(jsonb_build_object(
  'id',i->>'id','ingredientId',i->>'ingredientId','name',i->>'name',
  'quantity',trim_scale(round((i->>case when units='US' then 'usQuantity' else 'metricQuantity' end)::numeric*servings/(d->>'baseServings')::numeric,2)),
  'unit',i->>case when units='US' then 'usUnit' else 'metricUnit' end,
  'display',trim_scale(round((i->>case when units='US' then 'usQuantity' else 'metricQuantity' end)::numeric*servings/(d->>'baseServings')::numeric,2))::text||' '||
    (i->>case when units='US' then 'usUnit' else 'metricUnit' end)
 ) order by n) into items from jsonb_array_elements(d->'ingredients') with ordinality a(i,n);
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
  when 'Pantry' then exists(select 1 from jsonb_array_elements(v.document->'ingredients') i cross join jsonb_array_elements_text(pantry) p where p=i->>'ingredientId' or strpos(lower(p),lower(i->>'name'))>0)
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

begin;
insert into public.cnrecipe_ingredients(id,name) values('tomatoes','Tomatoes');
insert into public.cnrecipe_ingredients(id,name) values('eggs','Eggs');
insert into public.cnrecipe_ingredients(id,name) values('scallions','Scallions');
insert into public.cnrecipe_ingredients(id,name) values('cooking-oil','Cooking oil');
insert into public.cnrecipe_ingredients(id,name) values('salt','Salt');
insert into public.cnrecipe_ingredients(id,name) values('chicken-breast','Chicken breast');
insert into public.cnrecipe_ingredients(id,name) values('peanuts','Peanuts');
insert into public.cnrecipe_ingredients(id,name) values('dried-chilies','Dried chilies');
insert into public.cnrecipe_ingredients(id,name) values('light-soy-sauce','Light soy sauce');
insert into public.cnrecipe_ingredients(id,name) values('cooked-chilled-rice','Cooked chilled rice');
insert into public.cnrecipe_ingredients(id,name) values('noodles','Noodles');
insert into public.cnrecipe_ingredients(id,name) values('bok-choy','Bok choy');
insert into public.cnrecipe_ingredients(id,name) values('garlic','Garlic');
insert into public.cnrecipe_ingredients(id,name) values('tofu','Tofu');
insert into public.cnrecipe_ingredients(id,name) values('ground-pork','Ground pork');
insert into public.cnrecipe_ingredients(id,name) values('chili-bean-paste','Chili bean paste');
insert into public.cnrecipe_recipes(id,current_version,display_order) values('tomato',1,0);
insert into public.cnrecipe_versions(recipe_id,version,document) values('tomato',1,'{"id":"tomato","version":1,"name":"Tomato & Egg Stir-Fry","chineseName":"番茄炒蛋","minutes":15,"difficulty":"Beginner","vegetarian":true,"category":"Home-style","demo":true,"imageKey":"recipes/tomato/v1.jpg","bundledImage":"0.jpg","allergens":["Eggs"],"baseServings":2,"ingredients":[{"id":"tomato-v1-ingredient-1","ingredientId":"tomatoes","name":"Tomatoes","metricQuantity":2,"metricUnit":"medium","usQuantity":2,"usUnit":"medium"},{"id":"tomato-v1-ingredient-2","ingredientId":"eggs","name":"Eggs","metricQuantity":3,"metricUnit":"large","usQuantity":3,"usUnit":"large"},{"id":"tomato-v1-ingredient-3","ingredientId":"scallions","name":"Scallions","metricQuantity":2,"metricUnit":"stalks","usQuantity":2,"usUnit":"stalks"},{"id":"tomato-v1-ingredient-4","ingredientId":"cooking-oil","name":"Cooking oil","metricQuantity":15,"metricUnit":"mL","usQuantity":1,"usUnit":"tbsp"},{"id":"tomato-v1-ingredient-5","ingredientId":"salt","name":"Salt","metricQuantity":0.5,"metricUnit":"tsp","usQuantity":0.5,"usUnit":"tsp"}],"equipment":[{"id":"cooking-pan-and-utensils","name":"Cooking pan and utensils"}],"steps":[{"id":"tomato-v1-step-1","title":"Prepare the ingredients","instruction":"Cut the tomatoes into wedges, slice scallions, and beat the eggs in a separate bowl.","tip":"Get ingredients ready before heating the pan.","durationSeconds":0},{"id":"tomato-v1-step-2","title":"Cook the eggs","instruction":"Warm oil over medium heat. Add the eggs and gently stir until just set. Transfer them to a plate.","tip":"Keep the eggs tender. They will finish heating later.","durationSeconds":5},{"id":"tomato-v1-step-3","title":"Cook the tomatoes","instruction":"Add tomatoes and stir-fry until soft and juicy.","tip":"Medium heat is usually easier to control.","durationSeconds":100},{"id":"tomato-v1-step-4","title":"Combine and serve","instruction":"Return the eggs to the pan, season, and fold everything together.","tip":"Taste and serve while warm.","durationSeconds":0}]}'::jsonb);
insert into public.cnrecipe_recipes(id,current_version,display_order) values('kung',1,1);
insert into public.cnrecipe_versions(recipe_id,version,document) values('kung',1,'{"id":"kung","version":1,"name":"Kung Pao Chicken","chineseName":"宫保鸡丁","minutes":30,"difficulty":"Intermediate","vegetarian":false,"category":"Sichuan","demo":true,"imageKey":"recipes/kung/v1.jpg","bundledImage":"1.jpg","allergens":["Peanuts","Soy","Wheat (check sauce)"],"baseServings":2,"ingredients":[{"id":"kung-v1-ingredient-1","ingredientId":"chicken-breast","name":"Chicken breast","metricQuantity":300,"metricUnit":"g","usQuantity":10.6,"usUnit":"oz"},{"id":"kung-v1-ingredient-2","ingredientId":"peanuts","name":"Peanuts","metricQuantity":50,"metricUnit":"g","usQuantity":1.8,"usUnit":"oz"},{"id":"kung-v1-ingredient-3","ingredientId":"dried-chilies","name":"Dried chilies","metricQuantity":4,"metricUnit":"pieces","usQuantity":4,"usUnit":"pieces"},{"id":"kung-v1-ingredient-4","ingredientId":"light-soy-sauce","name":"Light soy sauce","metricQuantity":20,"metricUnit":"mL","usQuantity":4,"usUnit":"tsp"}],"equipment":[{"id":"cooking-pan-and-utensils","name":"Cooking pan and utensils"}],"steps":[{"id":"kung-v1-step-1","title":"Prepare","instruction":"Dice chicken evenly and prepare the sauce. Keep raw poultry separate from other food.","tip":"Wash hands and equipment after handling raw poultry.","durationSeconds":0},{"id":"kung-v1-step-2","title":"Build flavor","instruction":"Gently warm the aromatics and dried chilies in the pan.","tip":"Avoid burning the chilies.","durationSeconds":45},{"id":"kung-v1-step-3","title":"Cook chicken","instruction":"Cook the chicken and verify the thickest pieces reach 165°F / 74°C with a food thermometer.","tip":"Do not rely on color or a timer alone.","durationSeconds":0},{"id":"kung-v1-step-4","title":"Finish","instruction":"Add sauce and peanuts. Toss until evenly coated and serve.","tip":"Use the same verified recipe version throughout cooking.","durationSeconds":0}]}'::jsonb);
insert into public.cnrecipe_recipes(id,current_version,display_order) values('rice',1,2);
insert into public.cnrecipe_versions(recipe_id,version,document) values('rice',1,'{"id":"rice","version":1,"name":"Egg Fried Rice","chineseName":"蛋炒饭","minutes":15,"difficulty":"Beginner","vegetarian":true,"category":"Rice & Noodles","demo":true,"imageKey":"recipes/rice/v1.jpg","bundledImage":"2.jpg","allergens":["Eggs","Soy"],"baseServings":2,"ingredients":[{"id":"rice-v1-ingredient-1","ingredientId":"cooked-chilled-rice","name":"Cooked chilled rice","metricQuantity":300,"metricUnit":"g","usQuantity":10.6,"usUnit":"oz"},{"id":"rice-v1-ingredient-2","ingredientId":"eggs","name":"Eggs","metricQuantity":2,"metricUnit":"large","usQuantity":2,"usUnit":"large"},{"id":"rice-v1-ingredient-3","ingredientId":"scallions","name":"Scallions","metricQuantity":2,"metricUnit":"stalks","usQuantity":2,"usUnit":"stalks"},{"id":"rice-v1-ingredient-4","ingredientId":"light-soy-sauce","name":"Light soy sauce","metricQuantity":15,"metricUnit":"mL","usQuantity":1,"usUnit":"tbsp"}],"equipment":[{"id":"cooking-pan-and-utensils","name":"Cooking pan and utensils"}],"steps":[{"id":"rice-v1-step-1","title":"Prepare","instruction":"Break up properly chilled rice and beat eggs.","tip":"Use rice that has been cooled promptly and refrigerated safely.","durationSeconds":0},{"id":"rice-v1-step-2","title":"Scramble eggs","instruction":"Scramble eggs in a warm pan.","tip":"Keep stirring gently.","durationSeconds":50},{"id":"rice-v1-step-3","title":"Cook the rice","instruction":"Stir-fry rice until thoroughly heated throughout.","tip":"Separate clumps with your spatula.","durationSeconds":120},{"id":"rice-v1-step-4","title":"Season","instruction":"Add scallions and soy sauce, mix and serve immediately.","tip":"Avoid leaving cooked rice at room temperature.","durationSeconds":0}]}'::jsonb);
insert into public.cnrecipe_recipes(id,current_version,display_order) values('noodles',1,3);
insert into public.cnrecipe_versions(recipe_id,version,document) values('noodles',1,'{"id":"noodles","version":1,"name":"Scallion Oil Noodles","chineseName":"葱油拌面","minutes":20,"difficulty":"Beginner","vegetarian":true,"category":"Rice & Noodles","demo":true,"imageKey":"recipes/noodles/v1.jpg","bundledImage":"3.jpg","allergens":["Wheat","Soy"],"baseServings":2,"ingredients":[{"id":"noodles-v1-ingredient-1","ingredientId":"noodles","name":"Noodles","metricQuantity":200,"metricUnit":"g","usQuantity":7.1,"usUnit":"oz"},{"id":"noodles-v1-ingredient-2","ingredientId":"scallions","name":"Scallions","metricQuantity":4,"metricUnit":"stalks","usQuantity":4,"usUnit":"stalks"},{"id":"noodles-v1-ingredient-3","ingredientId":"light-soy-sauce","name":"Light soy sauce","metricQuantity":20,"metricUnit":"mL","usQuantity":4,"usUnit":"tsp"},{"id":"noodles-v1-ingredient-4","ingredientId":"cooking-oil","name":"Cooking oil","metricQuantity":30,"metricUnit":"mL","usQuantity":2,"usUnit":"tbsp"}],"equipment":[{"id":"cooking-pan-and-utensils","name":"Cooking pan and utensils"}],"steps":[{"id":"noodles-v1-step-1","title":"Prepare scallions","instruction":"Wash and dry scallions thoroughly, then slice.","tip":"Dry scallions reduce splattering.","durationSeconds":0},{"id":"noodles-v1-step-2","title":"Make scallion oil","instruction":"Cook the scallions gently in oil until fragrant.","tip":"Keep the heat low to prevent burning.","durationSeconds":240},{"id":"noodles-v1-step-3","title":"Cook noodles","instruction":"Boil noodles according to the package instructions.","tip":"Different noodles need different cooking times.","durationSeconds":0},{"id":"noodles-v1-step-4","title":"Toss","instruction":"Combine noodles with fragrant oil and seasonings.","tip":"Serve promptly.","durationSeconds":0}]}'::jsonb);
insert into public.cnrecipe_recipes(id,current_version,display_order) values('bok',1,4);
insert into public.cnrecipe_versions(recipe_id,version,document) values('bok',1,'{"id":"bok","version":1,"name":"Garlic Bok Choy","chineseName":"蒜蓉小白菜","minutes":12,"difficulty":"Beginner","vegetarian":true,"category":"Vegetables","demo":true,"imageKey":"recipes/bok/v1.jpg","bundledImage":"4.jpg","allergens":[],"baseServings":2,"ingredients":[{"id":"bok-v1-ingredient-1","ingredientId":"bok-choy","name":"Bok choy","metricQuantity":400,"metricUnit":"g","usQuantity":14.1,"usUnit":"oz"},{"id":"bok-v1-ingredient-2","ingredientId":"garlic","name":"Garlic","metricQuantity":3,"metricUnit":"cloves","usQuantity":3,"usUnit":"cloves"},{"id":"bok-v1-ingredient-3","ingredientId":"cooking-oil","name":"Cooking oil","metricQuantity":15,"metricUnit":"mL","usQuantity":1,"usUnit":"tbsp"},{"id":"bok-v1-ingredient-4","ingredientId":"salt","name":"Salt","metricQuantity":0.5,"metricUnit":"tsp","usQuantity":0.5,"usUnit":"tsp"}],"equipment":[{"id":"cooking-pan-and-utensils","name":"Cooking pan and utensils"}],"steps":[{"id":"bok-v1-step-1","title":"Wash","instruction":"Wash and drain the bok choy thoroughly.","tip":"Remove dirt between stems.","durationSeconds":0},{"id":"bok-v1-step-2","title":"Warm garlic","instruction":"Gently warm garlic in oil until fragrant.","tip":"Do not burn the garlic.","durationSeconds":40},{"id":"bok-v1-step-3","title":"Stir-fry","instruction":"Add greens and stir-fry until tender-crisp.","tip":"Stir frequently.","durationSeconds":120},{"id":"bok-v1-step-4","title":"Season","instruction":"Season lightly and serve immediately.","tip":"Taste before adding more salt.","durationSeconds":0}]}'::jsonb);
insert into public.cnrecipe_recipes(id,current_version,display_order) values('mapo',1,5);
insert into public.cnrecipe_versions(recipe_id,version,document) values('mapo',1,'{"id":"mapo","version":1,"name":"Mapo Tofu","chineseName":"麻婆豆腐","minutes":30,"difficulty":"Intermediate","vegetarian":false,"category":"Sichuan","demo":true,"imageKey":"recipes/mapo/v1.jpg","bundledImage":"5.jpg","allergens":["Soy","Wheat (check paste)"],"baseServings":2,"ingredients":[{"id":"mapo-v1-ingredient-1","ingredientId":"tofu","name":"Tofu","metricQuantity":350,"metricUnit":"g","usQuantity":12.3,"usUnit":"oz"},{"id":"mapo-v1-ingredient-2","ingredientId":"ground-pork","name":"Ground pork","metricQuantity":150,"metricUnit":"g","usQuantity":5.3,"usUnit":"oz"},{"id":"mapo-v1-ingredient-3","ingredientId":"chili-bean-paste","name":"Chili bean paste","metricQuantity":20,"metricUnit":"g","usQuantity":0.7,"usUnit":"oz"},{"id":"mapo-v1-ingredient-4","ingredientId":"scallions","name":"Scallions","metricQuantity":2,"metricUnit":"stalks","usQuantity":2,"usUnit":"stalks"}],"equipment":[{"id":"cooking-pan-and-utensils","name":"Cooking pan and utensils"}],"steps":[{"id":"mapo-v1-step-1","title":"Prepare","instruction":"Dice tofu and prepare the sauce ingredients.","tip":"Handle soft tofu carefully.","durationSeconds":0},{"id":"mapo-v1-step-2","title":"Cook pork","instruction":"Cook ground pork thoroughly, confirming 160°F / 71°C with a food thermometer.","tip":"Check temperature rather than relying on appearance.","durationSeconds":0},{"id":"mapo-v1-step-3","title":"Simmer","instruction":"Add sauce ingredients and tofu, then simmer gently.","tip":"Use gentle movements to keep tofu intact.","durationSeconds":180},{"id":"mapo-v1-step-4","title":"Serve","instruction":"Garnish and serve hot.","tip":"Taste before adjusting seasoning.","durationSeconds":0}]}'::jsonb);
commit;
