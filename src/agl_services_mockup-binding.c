/*
* Copyright (C) 2016-2019 "IoT.bzh"
* Author Fulup Ar Foll <fulup@iot.bzh>
* Author Romain Forlot <romain@iot.bzh>
* Author Sebastien Douheret <sebastien@iot.bzh>
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

#define _GNU_SOURCE
#include <afb/afb-binding.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <signal.h>

#include "agl_services_mockup-binding.h"

// Config Section definition (note: controls section index should match handle
// retrieval in HalConfigExec)
static CtlSectionT ctrlSections[] = {
    { .key = "plugins", .loadCB = PluginConfig },
    { .key = "onload", .loadCB = OnloadConfig },
    { .key = "controls", .loadCB = ControlConfig },
    { .key = "events", .loadCB = EventConfig },
    { .key = NULL }
};

static void ctrlapi_ping(afb_req_t request)
{
    static int count = 0;
    json_object* resJ;
    int rc;
    count++;
    AFB_REQ_NOTICE(request, "Controller:ping count=%d", count);
    rc = wrap_json_pack(&resJ, "{ss si}", "status", "pong", "count", count);
    if (rc < 0) {
        afb_req_fail_f(request, "ERROR", "wrap_json_pack rc=%d", rc);
        return;
    }
    afb_req_success(request, resJ, NULL);

    return;
}

static void ctrlapi_auth(afb_req_t request)
{
    afb_req_session_set_LOA(request, 1);
    afb_req_success(request, NULL, NULL);
}

static afb_verb_t CtrlApiVerbs[] = {
    /* VERB'S NAME         FUNCTION TO CALL         SHORT DESCRIPTION */
    { .verb = "ping_c", .callback = ctrlapi_ping, .info = "ping test for API" },
    { .verb = "auth", .callback = ctrlapi_auth, .info = "Authenticate session to raise Level Of Assurance of the session" },
    { .verb = NULL } /* marker for end of the array */
};

static int CtrlLoadStaticVerbs(afb_api_t apiHandle, afb_verb_t* verbs)
{
    int errcount = 0;

    for (int idx = 0; verbs[idx].verb; idx++) {
        errcount += afb_api_add_verb(apiHandle,
                        CtrlApiVerbs[idx].verb,
                        NULL,
                        CtrlApiVerbs[idx].callback,
                        (void*)&CtrlApiVerbs[idx],
                        CtrlApiVerbs[idx].auth,
                        0, 0);
    }

    return errcount;
};

static int CtrlInitOneApi(afb_api_t apiHandle)
{
    int err = 0;

    // retrieve section config from api handle
    CtlConfigT* ctrlConfig = (CtlConfigT*)afb_api_get_userdata(apiHandle);
    err = CtlConfigExec(apiHandle, ctrlConfig);
    if (err) {
        AFB_API_ERROR(apiHandle, "Error at CtlConfigExec step");
        return err;
    }

    return err;
}

static int CtrlLoadOneApi(void* cbdata, afb_api_t apiHandle)
{
    CtlConfigT* ctrlConfig = (CtlConfigT*)cbdata;

    // save closure as api's data context
    afb_api_set_userdata(apiHandle, ctrlConfig);

    // add static controls verbs
    int error = CtrlLoadStaticVerbs(apiHandle, CtrlApiVerbs);
    if (error) {
        AFB_API_ERROR(apiHandle, "CtrlLoadSection fail to register static V2 verbs");
        goto OnErrorExit;
    }

    // load section for corresponding API
    error = CtlLoadSections(apiHandle, ctrlConfig, ctrlSections);

    // declare an event event manager for this API;
    afb_api_on_event(apiHandle, CtrlDispatchApiEvent);

    // init API function
    afb_api_on_init(apiHandle, CtrlInitOneApi);

    afb_api_seal(apiHandle);

OnErrorExit:
    return error;
}

int afbBindingEntry(afb_api_t apiHandle)
{
    int status = 0;
    char* dirList;
    bool dirListNeedFree = FALSE;

    AFB_API_NOTICE(apiHandle, "Controller in afbBindingEntry");

    const char* dir = GetBindingDirPath(apiHandle);
    if (!dir) {
        dirList = CONTROL_CONFIG_PATH;
        dirListNeedFree = FALSE;
    } else {
        dirList = calloc(strlen(dir) + strlen("/etc"), sizeof(char));
        if (dirList == NULL) {
            AFB_API_ERROR(apiHandle, "afbBindingEntry: not enough memory");
            return ERROR;
        }
        dirListNeedFree = TRUE;
        strcpy(dirList, dir);
        strcat(dirList, "/etc");
        AFB_API_NOTICE(apiHandle, "Json config directory : %s", dirList);
    }

    const char* configPath = CtlConfigSearch(apiHandle, dirList, "");
    if (!configPath) {
        AFB_API_ERROR(apiHandle, "afbBindingEntry: No %s* config found in %s ", GetBinderName(), dirList);
        status = ERROR;
        goto _exit_afbBindingEntry;
    }

    // load config file and create API
    CtlConfigT* ctrlConfig = CtlLoadMetaData(apiHandle, configPath);
    if (!ctrlConfig) {
        AFB_API_ERROR(apiHandle,
            "afbBindingEntry No valid control config file in:\n-- %s",
            configPath);
        status = ERROR;
        goto _exit_afbBindingEntry;
    }

    if (!ctrlConfig->api) {
        AFB_API_ERROR(apiHandle,
            "afbBindingEntry API Missing from metadata in:\n-- %s",
            configPath);
        status = ERROR;
        goto _exit_afbBindingEntry;
    }

    AFB_API_NOTICE(apiHandle, "Controller API='%s' info='%s'", ctrlConfig->api,
        ctrlConfig->info);

    // create one API per config file (Pre-V3 return code ToBeChanged)
    afb_api_t handle = afb_api_new_api(apiHandle, ctrlConfig->api, ctrlConfig->info, 1, CtrlLoadOneApi, ctrlConfig);
    status = (handle) ? 0 : -1;

_exit_afbBindingEntry:
    if (dirListNeedFree)
        free(dirList);
    return status;
}
