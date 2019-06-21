/*
* Copyright (C) 2016 "IoT.bzh"
* Author Fulup Ar Foll <fulup@iot.bzh>
* Author Romain Forlot <romain@iot.bzh>
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
#include <stdio.h>
#include <string.h>
#include <time.h>

#include "agl_services_mockup-binding.h"

afb_api_t AFB_default;

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

    count++;
    AFB_REQ_NOTICE(request, "Controller:ping count=%d", count);
    afb_req_success(request, json_object_new_int(count), NULL);

    return;
}

void ctrlapi_auth(afb_req_t request)
{
    afb_req_session_set_LOA(request, 1);
    afb_req_success(request, NULL, NULL);
}

static afb_verb_t CtrlApiVerbs[] = {
    /* VERB'S NAME         FUNCTION TO CALL         SHORT DESCRIPTION */
    { .verb = "ping-global", .callback = ctrlapi_ping, .info = "ping test for API" },
    //    { .verb = "tstcan", .callback = ctrlapi_test_can, .info = "test can" },
    { .verb = "auth", .callback = ctrlapi_auth, .info = "Authenticate session to raise Level Of Assurance of the session" },
    { .verb = NULL } /* marker for end of the array */
};

static int CtrlLoadStaticVerbs(afb_api_t apiHandle, afb_verb_t* verbs)
{
    int errcount = 0;

    for (int idx = 0; verbs[idx].verb; idx++) {
        errcount += afb_api_add_verb(
            apiHandle, CtrlApiVerbs[idx].verb, NULL, CtrlApiVerbs[idx].callback,
            (void*)&CtrlApiVerbs[idx], CtrlApiVerbs[idx].auth, 0, 0);
    }

    return errcount;
};

static int CtrlInitOneApi(afb_api_t apiHandle)
{
    CtlConfigT* ctrlConfig = afb_api_get_userdata(apiHandle);

    return CtlConfigExec(apiHandle, ctrlConfig);
}

static int CtrlLoadOneApi(void* cbdata, afb_api_t apiHandle)
{
    CtlConfigT* ctrlConfig = (CtlConfigT*)cbdata;

    // save closure as api's data context
    afb_api_set_userdata(apiHandle, ctrlConfig);

    // add static controls verbs
    int err = CtrlLoadStaticVerbs(apiHandle, CtrlApiVerbs);
    if (err) {
        AFB_API_ERROR(apiHandle, "CtrlLoadSection fail to register static V2 verbs");
        return ERROR;
    }

    // load section for corresponding API
    err = CtlLoadSections(apiHandle, ctrlConfig, ctrlSections);

    // declare an event event manager for this API;
    afb_api_on_event(apiHandle, CtrlDispatchApiEvent);

    // init API function (does not receive user closure ???
    afb_api_on_init(apiHandle, CtrlInitOneApi);

    afb_api_seal(apiHandle);
    return err;
}

int afbBindingEntry(afb_api_t apiHandle)
{
    AFB_default = apiHandle;

    AFB_API_NOTICE(apiHandle, "Controller in afbBindingEntry");

    const char* dirList = getenv("CONTROL_CONFIG_PATH");
    if (!dirList)
        dirList = CONTROL_CONFIG_PATH;

    const char* configPath = CtlConfigSearch(apiHandle, dirList, "");
    if (!configPath) {
        AFB_API_ERROR(apiHandle, "CtlPreInit: No %s* config found in %s ", GetBinderName(), dirList);
        return ERROR;
    }

    // load config file and create API
    CtlConfigT* ctrlConfig = CtlLoadMetaData(apiHandle, configPath);
    if (!ctrlConfig) {
        AFB_API_ERROR(apiHandle,
            "CtrlBinding No valid control config file in:\n-- %s",
            configPath);
        return ERROR;
    }

    if (!ctrlConfig->api) {
        AFB_API_ERROR(apiHandle,
            "CtrlBinding API Missing from metadata in:\n-- %s",
            configPath);
        return ERROR;
    }

    AFB_API_NOTICE(apiHandle, "Controller API='%s' info='%s'", ctrlConfig->api,
        ctrlConfig->info);

    // create one API per config file (Pre-V3 return code ToBeChanged)
    int status = -! - !afb_api_new_api(apiHandle, ctrlConfig->api, ctrlConfig->info, 1, CtrlLoadOneApi, ctrlConfig);

    // config exec should be done after api init in order to enable onload to use newly defined ctl API.
    if (!status)
        status = CtlConfigExec(apiHandle, ctrlConfig);

    return status;
}
