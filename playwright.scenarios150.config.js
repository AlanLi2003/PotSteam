import base from './playwright.config.js';
export default {...base,testMatch:'scenarios150.spec.js',use:{...base.use,channel:'chrome'},reporter:[['json']],outputDir:'artifacts/scenarios-150-2026-11-01/test-output'};
