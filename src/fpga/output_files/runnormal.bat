reverse_bits.exe ap_core.rbf bitstream.rbf_r
copy /y bitstream.rbf_r "..\..\..\dist\Cores\Mazamars312.ataristarwars"
copy /y "..\..\..\dist\Cores\Mazamars312.ataristarwars\*" "j:\Cores\Mazamars312.ataristarwars\"
copy /y F:\Analogue\Analogue_Star_Wars\src\MPUBIOS\app\build.riscv.starwars_mpu_bios\starwars_mpu_bios.bin "F:\Analogue\Analogue_Star_Wars\dist\assets\ataristarwars\Mazamars312.ataristarwars\starwars_mpu_bios.bin"
copy /y "..\..\..\dist\assets\ataristarwars\Mazamars312.ataristarwars\*" "j:\Assets\ataristarwars\Mazamars312.ataristarwars\"