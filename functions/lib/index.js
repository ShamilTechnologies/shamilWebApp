"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.processPendingLogs = exports.syncAccessLogs = exports.validateAccess = void 0;
const admin = require("firebase-admin");
// We're importing functions in the other files, so don't need it here
// Initialize Firebase Admin
admin.initializeApp();
// Import our access control functions
const access_control_1 = require("./access-control");
Object.defineProperty(exports, "validateAccess", { enumerable: true, get: function () { return access_control_1.validateAccess; } });
const batch_processing_1 = require("./batch-processing");
Object.defineProperty(exports, "syncAccessLogs", { enumerable: true, get: function () { return batch_processing_1.syncAccessLogs; } });
Object.defineProperty(exports, "processPendingLogs", { enumerable: true, get: function () { return batch_processing_1.processPendingLogs; } });
//# sourceMappingURL=index.js.map