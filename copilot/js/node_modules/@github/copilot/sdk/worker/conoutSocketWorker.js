
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------------------------------------------*/
import __module from "module";
import __path from "path";
import __fs from "fs";
const __rootRequire = __module.createRequire(import.meta.url);
const __sharpRequire = __module.createRequire(__path.dirname(import.meta.url) + __path.sep + "sharp" + __path.sep + "index.js");
const __clipboardRequire = __module.createRequire(__path.dirname(import.meta.url) + __path.sep + "clipboard" + __path.sep + "index.js");
const require = (module) => {
    let req = __rootRequire;
    if (typeof module === "string" && module.startsWith("@img/")) {
        req = __sharpRequire;
    }
    if (typeof module === "string" && module.startsWith("@teddyzhu/")) {
        req = __clipboardRequire;
    }

    if (typeof module === "string" && __module.isBuiltin(module)) {
        return req(module);
    }

    const modulePath = __fs.realpathSync(req.resolve(module));
    const appPath = __fs.realpathSync(import.meta.dirname);
    const relativePath = __path.relative(appPath, modulePath);

    if (relativePath.startsWith("..")) {
        throw new Error("Requiring module outside of application is a security concern; module: " + modulePath + ", app: " + appPath);
    }

    return req(module);
};import __url from "url";
const __filename = __url.fileURLToPath(import.meta.url);
const __dirname = __path.dirname(__filename);
var a=(e=>typeof require<"u"?require:typeof Proxy<"u"?new Proxy(e,{get:(r,v)=>(typeof require<"u"?require:r)[v]}):e)(function(e){if(typeof require<"u")return require.apply(this,arguments);throw Error('Dynamic require of "'+e+'" is not supported')});var i=(e,r)=>()=>(r||e((r={exports:{}}).exports,r),r.exports);var u=i(t=>{"use strict";Object.defineProperty(t,"__esModule",{value:!0});t.getWorkerPipeName=void 0;function P(e){return e+"-worker"}t.getWorkerPipeName=P});var _=i(p=>{Object.defineProperty(p,"__esModule",{value:!0});var o=a("worker_threads"),s=a("net"),k=u(),c=o.workerData.conoutPipeName,n=new s.Socket;n.setEncoding("utf8");n.connect(c,function(){var e=s.createServer(function(r){n.pipe(r)});if(e.listen(k.getWorkerPipeName(c)),!o.parentPort)throw new Error("worker_threads parentPort is null");o.parentPort.postMessage(1)})});export default _();
