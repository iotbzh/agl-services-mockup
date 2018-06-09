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
    test_emul_can start

    test_emul_can start {"delay": 100, "count": 20, "repeat": 4, "repeat_delay": 5000}

    test_emul_can start {"delay": 100, "count": 20, "repeat": 4, "repeat_delay": 5000, "sleeptype": "actif"}
--]]
_MyContext = {}

function _run_onload_(source)
    AFB:notice(source, "--InLua-- ENTER _run_onload_ EMULATOR CAN\n")

    return 0
end

function _evt_catcher_(source, action, event)
    AFB:debug(source, "[-- evt_catcher --] action=%s, event=%s", Dump_Table(action), Dump_Table(event))
end


function _config_can_(source, args, query)
    AFB:debug(source, "--InLua-- ENTER _config_can_ query=%s", Dump_Table(query))

    if query == nil then
        AFB:fail(source, "Invalid parameter, channel must be set")
        return 0
    end

    if query["channel"] ~= _can_data[1].chan then
        AFB:fail(source, "Invalid can channel")
        return 0
    end

    local res = {
        ["status"] = "configured",
        ["channel"] = _can_data[1].chan
    }

    AFB:success(source, request, res)
    return 0
end

function _status_can_(source, args, query)
    AFB:debug(source, "--InLua-- ENTER _status_can_ query=%s", Dump_Table(query))

    -- SEB FIXME: workaround  LuaPushArgument: NULL object type (null)
    _MyContext["empty"] = ""

    local sts = {
        ["channel"] = _can_data[1].chan,
        ["context"] = _MyContext
    }

    AFB:debug(source, "SEB status %s", Dump_Table(sts))

    AFB:success(source, request, sts)
    return 0
end

local clock = os.clock
function sleep_ACTIF(n) -- seconds
    local t0 = clock()
    while clock() - t0 <= n do
    end
end

function sleep_OS(n)
    os.execute("sleep " .. tonumber(n))
end

function _Timer_Test_CB(source, timer, context)
    -- SEB: voir FULUP: pas arg1 source : normal ?
    local evtinfo = AFB:timerget(timer)

    AFB:debug(source, "[-- _Timer_Test_C --] evtInfo=%s", Dump_Table(evtinfo))

    local idx = #_can_data - evtinfo.count + 1
    if (evtinfo.count > #_can_data) then
        idx = #_can_data
    end

    local evtData = {
        ["count"] = evtinfo.count,
        ["timestamp"] = _can_data[idx].timestamp,
        ["value"] = _can_data[idx].val
    }
    AFB:debug(source, " Send idx = %d : %s", idx, Dump_Table(evtData))

    --send an event an event with count as value
    AFB:evtpush(source, _MyContext["event"], evtData)

    -- Should we repeat
    if evtinfo.count == 1 then
        local rptNum = _MyContext["query"]["repeat"]
        if (rptNum > 1) then
            _MyContext["query"]["repeat"] = rptNum - 1
            AFB:notice(source, "Repeat timer %s", Dump_Table(_MyContext["query"]["repeat"]))

            if _MyContext["query"]["sleeptype"] == "actif" then
                sleep_ACTIF(_MyContext["query"]["repeat_delay"] / 1000)
            else
                sleep_OS(_MyContext["query"]["repeat_delay"] / 1000)
            end

            AFB:timerset(source, _MyContext["timer"], "_Timer_Test_CB", _MyContext["context"])
        else
            AFB:notice(source, "Timer CAN END")
        end
        return -1
    end

    -- note when timerCB return!=0 timer is kill
    return 0
end

function _Timer_Test_repeat_CB(source, timer, context)
    local evtinfo = AFB:timerget(timer)

    AFB:debug(source, "[-- _Timer_Test_repeat --] evtInfo=%s, context=%s", Dump_Table(evtinfo), Dump_Table(context))

    if evtinfo.count > 0 then
        AFB:timerset(source, _MyContext["timer"], "_Timer_Test_CB", _MyContext["context"])
        return 0
    end

    -- stop timer
    AFB:debug(source, "Repeat timer end !")
    return -1
end

function _start_can_emulator_(source, args, query)
    AFB:debug(source, "--InLua-- ENTER _start_can_emulator_ query=%s", Dump_Table(query))

    _MyContext["context"] = {
        ["info"] = "CAN emulator Event"
    }

    -- if event does not exit create it now.
    if (_MyContext["event"] == nil) then
        _MyContext["event"] = AFB:evtmake(source, _can_data[1].chan)
    end

    if query == "null" then
        query = {}
    end

    -- if delay not defined default is 1s
    if (query["delay"] == nil) then
        query["delay"] = 1000
    end

    -- if count is not defined default is 10
    if (query["count"] == nil) then
        query["count"] = 10
    end

    -- we could use directly query but it is a sample
    local myTimer = {
        ["uid"] = AFB:getuid(source) .. " timer CAN events",
        ["label"] = query["label"],
        ["delay"] = query["delay"],
        ["count"] = query["count"]
    }
    _MyContext["timer"] = myTimer

    AFB:notice(source, "Test_Timer myTimer=%s", myTimer)

    -- subscribe to event
    local err = AFB:subscribe(source, _MyContext["event"])
    if err then
        AFB:fail(source, "Error subscribe")
        return 1
    end
    -- settimer take a table with delay+count as input (count==0 means infinite)
    AFB:timerset(source, myTimer, "_Timer_Test_CB", _MyContext["context"])

    if (query["repeat"] == nil) then
        query["repeat"] = 0
    end
    if (query["repeat_delay"] == nil) then
        query["repeat_delay"] = 1000
    end
    _MyContext["query"] = query

    AFB:success(source, request, myTimer)
    return 0
end

_can_data = {
    {["timestamp"] = "1520951000.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD0000000"},
    {["timestamp"] = "1520951000.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD0000000"},
    {["timestamp"] = "1520951000.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD1000000"},
    {["timestamp"] = "1520951000.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD2000000"},
    {["timestamp"] = "1520951000.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD3000000"},
    {["timestamp"] = "1520951000.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD4000000"},
    {["timestamp"] = "1520951001.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD5000000"},
    {["timestamp"] = "1520951001.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD6000000"},
    {["timestamp"] = "1520951001.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD7000000"},
    {["timestamp"] = "1520951001.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD8000000"},
    {["timestamp"] = "1520951001.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD9000000"},
    {["timestamp"] = "1520951002.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDA000000"},
    {["timestamp"] = "1520951002.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDB000000"},
    {["timestamp"] = "1520951002.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDC000000"},
    {["timestamp"] = "1520951002.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDD000000"},
    {["timestamp"] = "1520951002.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDE000000"},
    {["timestamp"] = "1520951003.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDF000000"},
    {["timestamp"] = "1520951003.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE0000000"},
    {["timestamp"] = "1520951003.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE1000000"},
    {["timestamp"] = "1520951003.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE2000000"},
    {["timestamp"] = "1520951003.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE3000000"},
    {["timestamp"] = "1520951004.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE4000000"},
    {["timestamp"] = "1520951004.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE5000000"},
    {["timestamp"] = "1520951004.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE6000000"},
    {["timestamp"] = "1520951004.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE7000000"},
    {["timestamp"] = "1520951004.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE8000000"},
    {["timestamp"] = "1520951005.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE9000000"},
    {["timestamp"] = "1520951005.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEA000000"},
    {["timestamp"] = "1520951005.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEB000000"},
    {["timestamp"] = "1520951005.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEC000000"},
    {["timestamp"] = "1520951005.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FED000000"},
    {["timestamp"] = "1520951006.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEE000000"},
    {["timestamp"] = "1520951006.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEF000000"},
    {["timestamp"] = "1520951006.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF0000000"},
    {["timestamp"] = "1520951006.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF1000000"},
    {["timestamp"] = "1520951006.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF2000000"},
    {["timestamp"] = "1520951007.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF3000000"},
    {["timestamp"] = "1520951007.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF4000000"},
    {["timestamp"] = "1520951007.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF5000000"},
    {["timestamp"] = "1520951007.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF6000000"},
    {["timestamp"] = "1520951007.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF7000000"},
    {["timestamp"] = "1520951008.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF8000000"},
    {["timestamp"] = "1520951008.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF9000000"},
    {["timestamp"] = "1520951008.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFA000000"},
    {["timestamp"] = "1520951008.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFB000000"},
    {["timestamp"] = "1520951008.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFC000000"},
    {["timestamp"] = "1520951009.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFD000000"},
    {["timestamp"] = "1520951009.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFE000000"},
    {["timestamp"] = "1520951009.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFF000000"},
    {["timestamp"] = "1520951009.600000", ["chan"] = "can0", ["val"] = "7E8#04410C2000000000"},
    {["timestamp"] = "1520951009.800000", ["chan"] = "can0", ["val"] = "7E8#04410C2001000000"},
    {["timestamp"] = "1520951010.000000", ["chan"] = "can0", ["val"] = "7E8#04410C2001000000"},
    {["timestamp"] = "1520951010.200000", ["chan"] = "can0", ["val"] = "7E8#04410C2000000000"},
    {["timestamp"] = "1520951010.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFF000000"},
    {["timestamp"] = "1520951010.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFE000000"},
    {["timestamp"] = "1520951010.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFD000000"},
    {["timestamp"] = "1520951011.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFC000000"},
    {["timestamp"] = "1520951011.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFB000000"},
    {["timestamp"] = "1520951011.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FFA000000"},
    {["timestamp"] = "1520951011.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF9000000"},
    {["timestamp"] = "1520951011.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF8000000"},
    {["timestamp"] = "1520951012.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF7000000"},
    {["timestamp"] = "1520951012.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF6000000"},
    {["timestamp"] = "1520951012.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF5000000"},
    {["timestamp"] = "1520951012.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF4000000"},
    {["timestamp"] = "1520951012.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF3000000"},
    {["timestamp"] = "1520951013.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF2000000"},
    {["timestamp"] = "1520951013.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF1000000"},
    {["timestamp"] = "1520951013.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FF0000000"},
    {["timestamp"] = "1520951013.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEF000000"},
    {["timestamp"] = "1520951013.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEE000000"},
    {["timestamp"] = "1520951014.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FED000000"},
    {["timestamp"] = "1520951014.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEC000000"},
    {["timestamp"] = "1520951014.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEB000000"},
    {["timestamp"] = "1520951014.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FEA000000"},
    {["timestamp"] = "1520951014.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE9000000"},
    {["timestamp"] = "1520951015.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE8000000"},
    {["timestamp"] = "1520951015.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE7000000"},
    {["timestamp"] = "1520951015.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE6000000"},
    {["timestamp"] = "1520951015.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE5000000"},
    {["timestamp"] = "1520951015.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE4000000"},
    {["timestamp"] = "1520951016.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE3000000"},
    {["timestamp"] = "1520951016.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE2000000"},
    {["timestamp"] = "1520951016.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE1000000"},
    {["timestamp"] = "1520951016.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FE0000000"},
    {["timestamp"] = "1520951016.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDF000000"},
    {["timestamp"] = "1520951017.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDE000000"},
    {["timestamp"] = "1520951017.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDD000000"},
    {["timestamp"] = "1520951017.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDC000000"},
    {["timestamp"] = "1520951017.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDB000000"},
    {["timestamp"] = "1520951017.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FDA000000"},
    {["timestamp"] = "1520951018.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD9000000"},
    {["timestamp"] = "1520951018.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD8000000"},
    {["timestamp"] = "1520951018.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD7000000"},
    {["timestamp"] = "1520951018.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD6000000"},
    {["timestamp"] = "1520951018.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD5000000"},
    {["timestamp"] = "1520951019.000000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD4000000"},
    {["timestamp"] = "1520951019.200000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD3000000"},
    {["timestamp"] = "1520951019.400000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD2000000"},
    {["timestamp"] = "1520951019.600000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD1000000"},
    {["timestamp"] = "1520951019.800000", ["chan"] = "can0", ["val"] = "7E8#04410C1FD0000000"}
}
