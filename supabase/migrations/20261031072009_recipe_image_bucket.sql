insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('recipe-images','recipe-images',true,5000000,array['image/jpeg']);
-- Public recipe photos are readable; no client INSERT/UPDATE/DELETE policy is granted.
