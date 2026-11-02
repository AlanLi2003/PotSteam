create or replace function cnrecipe_private.quote_document(d jsonb, servings integer, units text) returns jsonb
language plpgsql immutable set search_path=pg_catalog as $$
declare items jsonb;
begin
 if servings is null or units is null or servings not between 1 and 8 or units not in ('US','Metric') then
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

create or replace function cnrecipe_private.guard_entity() returns trigger
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
