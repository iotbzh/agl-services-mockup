--[[
  Copyright (C) 2018 "IoT.bzh"
  Author Sebastien Douheret <sebastien@iot.bzh>

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.


  NOTE: strict mode: every global variables should be prefixed by '_'

  Test commands:
    afb-client-demo 'localhost:2222/api?token=XXX&uuid=magic' can_app start
--]]
function _run_onload_(source)
    AFB:notice(source, "--InLua-- ENTER _run_onload_ CAN Application\n")

    local qr = {
        ["delay"] = 700,
        ["scenario"] = 0
    }

    -- Autostart onload (useful for debug)
    -- _start_app_(source, nil, qr)

    return 0
end

function _evt_catcher_(source, action, event)
    AFB:notice(source, "RECV EVENT=%s", Dump_Table(event))

    if (event.count % 10) == 0 then
        AFB:notice(source, "Request can_emul status")
        local err, response = AFB:servsync(source, "can_emul", "status", {})
        if (err) then
            AFB:error(source, "--LUA:_start_app_ can_emul status response=%s", response)
            return 1
        end
    end

    if ((event.count % 10) == 0) and (math.random(5) == 1) then
        AFB:notice(source, "Request can_emul config with failure")
        local err, response = AFB:servsync(source, "can_emul", "config", {})
        AFB:debug(source, "--LUA:_start_app_ config status response=%s", response)
    end

end

function _start_app_(source, args, query)
    AFB:debug(source, "--InLua-- ENTER _start_app_ query=%s", Dump_Table(query))

    local err, response = AFB:servsync(source, "can_emul", "status", {})
    if (err) then
        AFB:error(source, "--LUA:_start_app_ can_emul status response=%s", response)
        return 1
    end

    if query == "null" then
        query = {}
    end
    if query.scenario == nil then
        query.scenario = 1
    end

    if query.scenario == 0 then
        query.delay = 100
        query.count = 30
        query.sleeptype = "actif"
        query["repeat_delay"] = 2000
        query["repeat"] = 100
    elseif query.scenario == 1 then
        query.delay = 1000
        query.count = 100
        query.sleeptype = "actif"
        query["repeat_delay"] = 5000
        query["repeat"] = 100
    elseif query.scenario == 2 then
        query.delay = 100
        query.count = 200
        query.sleeptype = "os"
        query["repeat_delay"] = 5000
        query["repeat"] = 500
    elseif query.scenario == 3 then
        query.delay = 10
        query.count = 200
        query.sleeptype = "actif"
        query["repeat_delay"] = 2000
        query["repeat"] = 500
    end

    AFB:notice(source, "Start scenario %d : %s\n", query.scenario, Dump_Table(query))

    err, response = AFB:servsync(source, "can_emul", "start", query)
    if (err) then
        AFB:error(source, "--LUA:_start_app_ can_emul status response=%s", response)
        return 1
    end

    --if request ~= nil then
    AFB:success(source, request, {["status"] = "CAN app running", ["scenario"]=query.scenario})
    --end
end

function sleep_OS(n)
    os.execute("sleep " .. tonumber(n))
end
