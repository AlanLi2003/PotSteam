-- Source-faithful variable quantities and whole-item batches; existing numeric recipes retain their contract.
create or replace function cnrecipe_private.quote_document(d jsonb, servings integer, units text) returns jsonb
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
