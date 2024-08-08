#!/usr/bin/env node

global.__rootDirectory = __dirname + '/dist/';

require('./dist/language-server.js')
