import {readFile,writeFile,copyFile,mkdir} from 'node:fs/promises';
import {database} from '../backend/database.mjs';
const root=new URL('../',import.meta.url);
await copyFile(new URL('backend/api.mjs',root),new URL('supabase/functions/cnrecipe/api.mjs',root));
await mkdir(new URL('ios/CNrecipe/Content',root),{recursive:true});
const {db,rpc}=await database();
await writeFile(new URL('ios/CNrecipe/Content/catalog.json',root),JSON.stringify(await rpc('cnrecipe_catalog')));
await db.close();console.log('Shared Edge handler and server-generated offline catalog prepared.');
