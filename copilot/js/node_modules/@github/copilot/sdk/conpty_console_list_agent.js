
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
var d=(e=>typeof require<"u"?require:typeof Proxy<"u"?new Proxy(e,{get:(r,o)=>(typeof require<"u"?require:r)[o]}):e)(function(e){if(typeof require<"u")return require.apply(this,arguments);throw Error('Dynamic require of "'+e+'" is not supported')});var v=(e,r)=>()=>(r||e((r={exports:{}}).exports,r),r.exports);var f=v(t=>{"use strict";Object.defineProperty(t,"__esModule",{value:!0});t.loadNativeModule=t.assign=void 0;function M(e){for(var r=[],o=1;o<arguments.length;o++)r[o-1]=arguments[o];return r.forEach(function(a){return Object.keys(a).forEach(function(s){return e[s]=a[s]})}),e}t.assign=M;function m(e){for(var r=["build/Release","build/Debug","prebuilds/"+process.platform+"-"+process.arch],o=["..","."],a,s=0,u=r;s<u.length;s++)for(var p=u[s],l=0,c=o;l<c.length;l++){var b=c[l],i=b+"/"+p;try{return{dir:i,module:d(i+"/"+e+".node")}}catch(P){a=P}}throw new Error("Failed to load native module: "+e+".node, checked: "+r.join(", ")+": "+a)}t.loadNativeModule=m});var E=v(h=>{Object.defineProperty(h,"__esModule",{value:!0});var y=f(),j=y.loadNativeModule("conpty_console_list").module.getConsoleProcessList,g=parseInt(process.argv[2],10),n=[];if(g>0)try{n=j(g)}catch{n=[]}process.send({consoleProcessList:n});process.exit(0)});export default E();
