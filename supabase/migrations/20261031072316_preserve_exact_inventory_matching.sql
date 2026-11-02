create or replace function public.cnrecipe_catalog(p_query text default '',p_filter text default 'All',p_pantry jsonb default '[]',p_allergens jsonb default '[]') returns jsonb
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
