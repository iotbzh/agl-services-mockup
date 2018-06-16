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

    afb-client-demo 'localhost:1111/api?token=HELLO&uuid=magic'
    gps_emul start

    gps_emul start {"sample_rate": 1000,}

    gps_emul start {"sample_rate": 1000, "count": 200}
--]]
_MyContext = {
    ["sample_rate"] = 1000
}

function _run_onload_(source)
    AFB:notice(source, "--InLua-- ENTER _run_onload_ EMULATOR GPS\n")

    return 0
end

function _evt_catcher_(source, action, event)
    AFB:debug(source, "[-- evt_catcher --] action=%s, event=%s", Dump_Table(action), Dump_Table(event))
end


function _config_gps_(source, args, query)

    AFB:debug(source, "--InLua-- ENTER _config_gps_ query=%s", Dump_Table(query))

    if query == nil then
        AFB:fail(source, "Invalid parameter, channel must be set")
        return 0
    end
    if query.channel ~= "gps0" then
        AFB:fail(source, "Invalid gps channel")
        return 0
    end
    if query["sample_rate"] and query.sample_rate > 0 then
        _MyContext.sample_rate = query.sample_rate
    end

    local res = {
        ["status"] = "gps0 configured",
    }

    AFB:success(source, res)
    return 0
end

function _status_gps_(source, args, query)
    if query == nil then
        AFB:fail(source, "Invalid parameter, channel must be set")
        return 0
    end
    if query.channel ~= "gps0" then
        AFB:fail(source, "Invalid gps channel")
        return 0
    end

    local sts = {
        ["channel"] = "gps0",
        ["sample_rate"] = _MyContext.sample_rate
    }
    AFB:success(source, sts)
    return 0
end


_latitude=46.736606
_longitude=4.514434

function _Timer_Test_CB(source, timer, context)
    local evtinfo = AFB:timerget(timer)

    AFB:debug(source, "[-- _Timer_Test_C --] evtInfo=%s", Dump_Table(evtinfo))
    AFB:debug(source, "[-- _Timer_Test_C --] context=%s", Dump_Table(context))

    local timestamp = os.time(os.date("!*t"))
    _latitude = _latitude + math.random(-5, 5)
    _longitude = _longitude + math.random(-2, 2)

    local evtData = {
        ["timestamp"] = timestamp,
        ["latitude"] = _latitude,
        ["longitude"] =_longitude,
    }
    AFB:debug(source, " Send GPS event : %s", Dump_Table(evtData))

    --send an event an event with count as value
    AFB:evtpush(source, _MyContext.event, evtData)

    if evtinfo.count == 0 then
        AFB:notice(source, "Timer GPS END")
        return -1
    end

    -- note when timerCB return!=0 timer is kill
    return 0
end


function _start_gps_emulator_(source, args, query)
    AFB:debug(source, "--InLua-- ENTER _start_gps_emulator_ query=%s", Dump_Table(query))

    _MyContext.context = {
        ["info"] = "GPS emulator Event"
    }
    -- if event does not exit create it now.
    if (_MyContext.event == nil) then
        _MyContext.event = AFB:evtmake(source, "gps0")
    end

    if query == "null" then
        query = {}
    end

    _MyContext.context.query = query

    -- if sample_rate not defined default is 1s
    _MyContext.context.sample_rate = _MyContext.sample_rate

    if (query.sample_rate and query.sample_rate > 0) then
        _MyContext.sample_rate = query.sample_rate
    end

    -- if count is not defined default is infinite
    _MyContext.context.count = query.count
    if (query.count == nil) then
        _MyContext.context.count = 1000000000
    end

    -- we could use directly query but it is a sample
    local myTimer = {
        ["uid"] = AFB:getuid(source) .. " timer GPS events",
        ["label"] = query.label,
        ["delay"] =  _MyContext.context.sample_rate,
        ["count"] =  _MyContext.context.count
    }

    _MyContext.timer = myTimer

    AFB:notice(source, "Test_Timer myTimer=%s", myTimer)

    -- subscribe to event
    local err = AFB:subscribe(source, _MyContext.event)
    if err then
        AFB:fail(source, "Error subscribe")
        return 1
    end

    -- settimer take a table with delay+count as input (count==0 means infinite)
    AFB:timerset(source, myTimer, "_Timer_Test_CB", _MyContext.context)

    AFB:success(source, myTimer)
    return 0
end
