import std.stdio;
import std.file;
import std.string;
import std.conv;
//import std.exception;

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

enum State:int {
    INITIAL= 0,
    SETTING,
    WORKING,
    TESTING,
    EXITING
};

State progState= State.INITIAL;




void main()
{

    File conf;

    while (progState != State.EXITING) {
        writeln("Inside ", progState);
            switch (progState) {
                case (State.INITIAL):
                    readConfig(conf);
                    break;

                case (State.SETTING):
                    if (setPassword(passWord.ptr)) {
                        conf.writeln(passWord);
                        progState= State.TESTING;
                    }
                    break;

                case (State.WORKING):
                    if(!passWordAccepted) {
                        writeln("Please enter key:");
                        write(">> ");
                        auto input= chomp(readln());
                        if (passWord == input) {
                            passWordAccepted= true;
                            writeln("Password is OK!");
                        }
                    }
                    else {
                        if(getDevice() > 0) {
                            readCommand();
                        }
                    }
                    break;

                case (State.TESTING):
                    searchDevice();
                    progState= State.EXITING;
                    break;

                default:
                    throw new Exception(format("Unknown program state: %s", progState));
            }

        //if (progState > 4) {
        //    throw new Exception(writeln("Unknown program state ", progState));
        //}
    }
    writeln("Outside ", progState);
}

void readConfig(File conf) {
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
        writeln("Password accepted!");
        for(int i= 0; i < 4; i++) {
            *(passWord)= (pass[i]);
            passWord++;
        }
        return 1;
    }
}

void readCommand() {
    writeln("Commands: ON, OFF, TGL, READ, HELP, EXIT");
    write(">> ");
    auto comm= chomp(readln()).toUpper;
    if (comm.length == 2) {
        if (comm[0..2] == "ON") {
            VPSetOutputSinglePort(deviceSerialNumber, 1, 1);
        }
        else {
            writeln("Illegal command");
        }
    }
    else if (comm.length == 3) {
        if (comm[0..3] == "OFF") {
            VPSetOutputSinglePort(deviceSerialNumber, 0, 1);
        }
        else if (comm[0..3] == "TGL") {
            ushort ports;
            VPGetOutputPorts(deviceSerialNumber, &ports);
            if (!ports&0x01) { // Check if channel 0 is LOW
                VPSetOutputSinglePort(deviceSerialNumber, 1, 1);
            }
            else {
                VPSetOutputSinglePort(deviceSerialNumber, 0, 1);
            }
        }
        else {
            writeln("Illegal command");
        }
    }
    else if (comm.length == 4) {
        if (comm[0..4] == "EXIT") {
            progState= State.EXITING;
        }
        else if (comm[0..4] == "HELP") {
            writeln("Help is not ready yet");
        }
        else if (comm[0..4] == "READ") {
            writeln("Relay channels : ");
            ushort ports;
            VPGetOutputPorts(deviceSerialNumber, &ports);
            for(int i= 15;i >= 0; i--) {
                write("channel ", i, " : \t");
                write((((ports >> i)&0x01)?"ON":"OFF"));
                write("\n");
            }
        }
        else {
            writeln("Illegal command");
        }
    }
    else {
            writeln("Illegal command");
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
    if(searchDevice()) {
        ubyte devId0, devId1;
        VPGetDevInfo(1, &devId0, &devId1, &deviceSerialNumber);
        deviceId= [devId0, devId1];
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
