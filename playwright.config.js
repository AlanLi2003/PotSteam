import { defineConfig } from '@playwright/test';
export default defineConfig({testDir:'tests',testMatch:'**/*.spec.js',use:{baseURL:'http://127.0.0.1:4180',viewport:{width:390,height:760}},webServer:{command:'python3 -m http.server 4180 --directory ios/CNrecipe/Web',url:'http://127.0.0.1:4180',reuseExistingServer:true},reporter:[['list'],['html',{open:'never'}]]});
