
/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------------------------------------------*/
import __module from "module";
import __path from "path";
import __fs from "fs";
const __rootRequire = __module.createRequire(import.meta.url);
const __appPath = __fs.realpathSync(import.meta.dirname);
const __sharpEntrypoint = __path.join(__appPath, "sharp", "index.js");
const __clipboardEntrypoint = __path.join(__appPath, "clipboard", "index.js");
const __foundryEntrypoint = __path.join(__appPath, "foundry-local-sdk", "index.js");
const __pvRecorderEntrypoint = __path.join(__appPath, "pvrecorder", "index.js");
const __koffiEntrypoint = __path.join(__appPath, "koffi", "index.js");
const __sharpRequire = __fs.existsSync(__sharpEntrypoint)
    ? __module.createRequire(__sharpEntrypoint)
    : __rootRequire;
const __clipboardRequire = __fs.existsSync(__clipboardEntrypoint)
    ? __module.createRequire(__clipboardEntrypoint)
    : __rootRequire;
const __foundryRequire = __fs.existsSync(__foundryEntrypoint)
    ? __module.createRequire(__foundryEntrypoint)
    : __rootRequire;
const __pvRecorderRequire = __fs.existsSync(__pvRecorderEntrypoint)
    ? __module.createRequire(__pvRecorderEntrypoint)
    : __rootRequire;
const __koffiRequire = __fs.existsSync(__koffiEntrypoint)
    ? __module.createRequire(__koffiEntrypoint)
    : __rootRequire;
const __isVendoredNativeModule = (module) =>
    typeof module === "string" &&
    (module.startsWith("@img/") || module.startsWith("@teddyzhu/") || module === "foundry-local-sdk" || module === "@picovoice/pvrecorder-node" || module === "koffi");
const require = (module) => {
    let req = __rootRequire;
    if (typeof module === "string" && module.startsWith("@img/")) {
        req = __sharpRequire;
    }
    if (typeof module === "string" && module.startsWith("@teddyzhu/")) {
        req = __clipboardRequire;
    }
    if (module === "foundry-local-sdk") {
        req = __foundryRequire;
    }
    if (module === "@picovoice/pvrecorder-node") {
        req = __pvRecorderRequire;
    }
    if (module === "koffi") {
        // koffi is vendored at <appPath>/koffi/ as a flat copy
        // (not under node_modules/), so 'koffi' as a package name
        // doesn't resolve through the standard module-resolution
        // walk. Load koffi's entry file by absolute path when
        // it's vendored; fall back to standard resolution
        // (dev: from repo node_modules) otherwise.
        if (__fs.existsSync(__koffiEntrypoint)) {
            return __koffiRequire(__koffiEntrypoint);
        }
        req = __koffiRequire;
    }

    if (typeof module === "string" && (__module.isBuiltin(module) || __isVendoredNativeModule(module))) {
        return req(module);
    }

    const modulePath = __fs.realpathSync(req.resolve(module));
    const relativePath = __path.relative(__appPath, modulePath);

    if (relativePath.startsWith("..")) {
        throw new Error("Requiring module outside of application is a security concern; module: " + modulePath + ", app: " + __appPath);
    }

    return req(module);
};import __url from "url";
const __filename = __url.fileURLToPath(import.meta.url);
const __dirname = __path.dirname(__filename);
var d=(e=>typeof require<"u"?require:typeof Proxy<"u"?new Proxy(e,{get:(r,o)=>(typeof require<"u"?require:r)[o]}):e)(function(e){if(typeof require<"u")return require.apply(this,arguments);throw Error('Dynamic require of "'+e+'" is not supported')});var v=(e,r)=>()=>(r||e((r={exports:{}}).exports,r),r.exports);var f=v(t=>{"use strict";Object.defineProperty(t,"__esModule",{value:!0});t.loadNativeModule=t.assign=void 0;function M(e){for(var r=[],o=1;o<arguments.length;o++)r[o-1]=arguments[o];return r.forEach(function(a){return Object.keys(a).forEach(function(s){return e[s]=a[s]})}),e}t.assign=M;function m(e){for(var r=["build/Release","build/Debug","prebuilds/"+process.platform+"-"+process.arch],o=["..","."],a,s=0,u=r;s<u.length;s++)for(var p=u[s],l=0,c=o;l<c.length;l++){var b=c[l],i=b+"/"+p;try{return{dir:i,module:d(i+"/"+e+".node")}}catch(P){a=P}}throw new Error("Failed to load native module: "+e+".node, checked: "+r.join(", ")+": "+a)}t.loadNativeModule=m});var E=v(h=>{Object.defineProperty(h,"__esModule",{value:!0});var y=f(),j=y.loadNativeModule("conpty_console_list").module.getConsoleProcessList,g=parseInt(process.argv[2],10),n=[];if(g>0)try{n=j(g)}catch{n=[]}process.send({consoleProcessList:n});process.exit(0)});export default E();
