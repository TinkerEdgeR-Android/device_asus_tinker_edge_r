These files are required to flash the Android TinkerOS image to the attached
Tinker Edge R board.

Note: Do not power the board or connect any cable until instructed to do so.

Before you begin the flashing procedure, please make sure the board is
completely powered off.

1. Connect the USB Type-C cable to the USB Type-C port on the board and your
   host computer.
2. Short the MASKROM mode header and power on the board. The board should
   boot up to the MASKROM mode for download.
3. Make sure the driver is installed if the host computer is equipped with
   Windows.
4. Run the scripts flash.bat for Windows or flash.sh for Linux in this
   directory.

* For Windows, you can find DriverAssitant package in the sub-directory tools.
Please unzip it and execute DriverInstall.exe to install the driver.
