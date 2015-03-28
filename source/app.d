import std.stdio;
import std.file;
import std.string;
import std.conv;

pragma (lib, "vports.lib");

extern (C)
{
    //ubyte GetInputReportSN(ushort sn, ubyte rep, ubyte &P1, ubyte &P2);
    //ubyte SetOutputReportSN(ushort sn, ubyte rep, ubyte P1, ubyte P2);
    ubyte VPGetDevCount();
    ubyte VPGetDevInfo(ubyte dnum, ubyte* id1, ubyte* id2, ushort* sn);
    //ubyte VPGetInputPorts(ushort sn, ushort &ports);
    //ubyte VPGetInputPortsLatch(ushort sn, ushort &ports);
    ubyte VPGetOutputPorts(ushort sn, ushort* ports);
    //ubyte VPSetOutputPorts(ushort sn, ushort ports);
    ubyte VPSetOutputSinglePort(ushort sn, ubyte setorclear, ubyte port);
/*
    ubyte VPOFFONOutputPortsTime(ushort sn,
            ushort portsoffT,
            ushort portsonT,
            ubyte ONOFFtime);
*/
/*
    ubyte VPStartWD(ushort sn,
            ubyte wdtime,
            ushort portsoff,
            ushort portson,
            ushort portsoffT,
            ushort portsonT,
            ubyte ONOFFtime);
*/
    //ubyte VPStopWD(ushort sn);
    //ubyte VPResetWD(ushort sn);
}

// VPGetDevCount - возвращает количество подключенных устрйоств
// VPGetDevInfo - возвращает в переменных ld1, ld2 и sn - параметры устройства с номером dnum
// VPSetOutputSinglePort - установить состояние выходов (setorclear: 1= ON, 0= OFF; sn = 0 - все найденные устрйоства)


immutable int passWordLength= 4; /////////// MAGIC!
char[passWordLength] passWord;
string configFileName= "./config.ini";
ushort deviceSerialNumber;
ubyte[2] deviceId;
bool passWordAccepted= false;

auto relayState= 0;

enum State:int {
    INITIAL= 0,
    SETTING,
    WORKING,
    TESTING,
    EXITING
};


void main()
{
    State progState= State.INITIAL;
    File conf;

    if(!exists(configFileName)) {
        try{
            conf= File(configFileName, "w");
        }
        catch (std.exception.ErrnoException exc) {
            writeln("Program directory is write-protected. Can not create configuration file");
        }
        finally {
            conf.close();
        }
        writeln("Configuration file ", configFileName, " created");
        progState= State.SETTING;
    }
    else {
        conf= File(configFileName, "r");
        writeln("Configuration file ", configFileName, " opened");

            auto dat= chomp(conf.readln());
            if ((dat.length != 0)&&(!conf.eof())) {
                passWord= dat.dup;
                progState= State.WORKING;
                conf.close();
            }
            else {
                conf.close();
                conf.open(configFileName, "w");
                progState= State.SETTING;
            }

    }
    while (progState != State.EXITING) {
        writeln("Inside while State: ", progState); ///////////////////
        switch (progState) {
            case State.INITIAL:

                break;

            case State.SETTING:
                if (setPassword(passWord.ptr)) {
                    conf.writeln(passWord);
                    progState= State.TESTING;
                }
                break;

            case State.WORKING:
                if(!passWordAccepted) {
                    writeln("Please enter key:");
                    write(">> ");
                    auto input= chomp(readln());
                    if (passWord == input) {
                        passWordAccepted= true;
                    }
                }
                else {
                    if(searchDevice() > 0) {
                        writeln("Commands: ON, OFF, TGL, HELP, EXIT");
                        write(">> ");
                        auto comm= chomp(readln());
                        if (comm.length == 2) {
                            if (comm[0..2] == "ON") {
                                if(VPSetOutputSinglePort(deviceSerialNumber, 1, 1)) {
                                    continue;
                                }
                            }
                        }
                        else if (comm.length == 3) {
                            if (comm[0..3] == "OFF") {
                                if(VPSetOutputSinglePort(deviceSerialNumber, 0, 1)) {
                                    continue;
                                }
                            }
                            else if (comm[0..3] == "TGL") {
                                ushort ports;
                                VPGetOutputPorts(deviceSerialNumber, &ports);
                                if (!ports&0x01) { // Check if channel 0 is LOW
                                    if(VPSetOutputSinglePort(deviceSerialNumber, 1, 1)) {
                                        continue;
                                    }
                                }
                                else {
                                    if(VPSetOutputSinglePort(deviceSerialNumber, 0, 1)) {
                                        continue;
                                    }
                                }
                            }
                        }
                        else if (comm.length == 4) {
                            if (comm[0..4] == "EXIT") {
                                progState= State.EXITING;
                            }
                            else if (comm[0..4] == "HELP") {
                                writeln("Help is not ready yet");
                            }
                        }
                    }
                }
                break;

            case State.TESTING:
                searchDevice();
                progState= State.EXITING;
                break;

            default:
                progState= State.EXITING;
                break;
        }

        continue;
    }

    writeln("Outside while State: ", progState);
}

uint setPassword(char * passWord) {
    writeln("Write new passWord");
    auto pass= chomp(readln());
    if (pass.length > passWordLength) {
        writeln("Too long password");
        return 0;
    }
    else if (pass.length < passWordLength) {
        writeln("Too short password");
        return 0;
    }
    else {
        writeln("Password OK!");
        for(int i= 0; i < 4; i++) {
            *(passWord)= (pass[i]);
            passWord++;
        }
        return 1;
    }
}

uint searchDevice() {
    auto devCount= VPGetDevCount();
    //auto devCount= 0;
    writeln("Found ", devCount, " devices");
    if (devCount) {
        return 1;
    }
    else {
        return 0;
    }
}

uint getDevice() {
    if(searchDevice) {
        VPGetDevInfo(1, &(deviceId[0]), &(deviceId[1]), &deviceSerialNumber);
        return 1;
    }
    return 0;
}

void stop(ushort message) {
    writeln(message);
    writeln("Press any key for continue...");
    readln();
}

void stop(string message) {
    writeln(message);
    writeln("Press any key for continue...");
    readln();
}

void stop(State message) {
    writeln(message);
    writeln("Press any key for continue...");
    readln();
}
