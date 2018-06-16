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
        ["sample_rate"] = 2000
    }

    -- SEB
    --_start_app_(source, nil, qr)

    return 0
end

function _evt_catcher_(source, action, event)
    AFB:notice(source, "RECV EVENT=%s", Dump_Table(event))

    if (math.random(30) == 1) then
        local gps_chan = "gps" .. math.random(0, 3)
        local err, response = AFB:servsync(source, "gps_emul", "status", {["channel"] = gps_chan})
        if (err) then
            AFB:error(source, "Request gps_emul status %s ERROR response=%s", gps_chan, response)
            return 1
        else
            AFB:notice(source, "Request gps_emul status OK (%s)", gps_chan)
        end
    end
end

function _start_app_(source, args, query)
    AFB:debug(source, "--InLua-- ENTER _start_app_ query=%s", Dump_Table(query))

    local qr = {
        ["channel"] = "gps0"
    }

    local err, response = AFB:servsync(source, "gps_emul", "status", qr)
    if (err) then
        AFB:error(source, "--LUA:_start_app_ gps_emul status response=%s", response)
        return 1
    end

    local qrCfg = qr
    if (query.sample_rate and query.sample_rate > 0) then
        qrCfg.sample_rate = query.sample_rate
    end

    err, response = AFB:servsync(source, "gps_emul", "config", qrCfg)
    if (err) then
        AFB:error(source, "--LUA:_start_app_ gps_emul config response=%s", response)
        return 1
    end

    sleep(0.5)

    err, response = AFB:servsync(source, "gps_emul", "status", qr)
    if (err) then
        AFB:error(source, "--LUA:_start_app_ gps_emul status 2 response=%s", response)
        return 1
    end
    AFB:notice(source, "Start GPS: cfg %s\n", Dump_Table(response))
    local cfg = response

    AFB:notice(source, "Start GPS: cfg %s\n", Dump_Table(cfg))

    err, response = AFB:servsync(source, "gps_emul", "start", qr)
    if (err) then
        AFB:error(source, "--LUA:_start_app_ gps_emul start response=%s", response)
        return 1
    end

    -- SEB FIXME: but how ??? no way to access source.request
    -- if source.request ~= nil then
        AFB:success(source, {["status"] = "GPS app running", ["config"] = cfg})
    --end
end

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end
