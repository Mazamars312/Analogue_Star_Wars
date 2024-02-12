-- Copyright (c) 2003,2004 Adam Wozniak
--
-- Distributed under the Gnu General Public License
--
-- riot.vhdl ; VHDL implementation of Atari 2600 RIOT chip
-- Copyright (C) 2003,2004 Adam Wozniak
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--
-- The author may be contacted
-- by email: adam@cuddlepuddle.org
-- by snailmail: Adam Wozniak, 1352 - 14th Street, Los Osos, CA 93402

-- RIOT implementation

-- Works with :
--   Space Invaders
--   Asteroids
--   Missile Command
--   Pesco
--   Pitfall
--   Cosmic Ark

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity r6532 is
   port(
		phi2    : in  std_logic;
		res_n   : in  std_logic;
		CS1     : in  std_logic;
		CS2_n   : in  std_logic;
		RS_n    : in  std_logic;
		R_W     : in  std_logic;
		addr    : in  std_logic_vector(6 downto 0);
		dataIn  : in  std_logic_vector(7 downto 0);
		dataOut : out std_logic_vector(7 downto 0) := "00000000";
		pa      : in std_logic_vector(7 downto 0);
		pa_out  : out std_logic_vector(7 downto 0) := "00000000";
		pa_dir  : out std_logic_vector(7 downto 0) := "00000000";
		pb      : in std_logic_vector(7 downto 0);
		pb_out  : out std_logic_vector(7 downto 0) := "00000000";
		pb_dir  : out std_logic_vector(7 downto 0) := "00000000";
		IRQ_n   : out std_logic := '1'
	);
end r6532;

architecture arch of r6532 is
   type ram_t is array (127 downto 0) of std_logic_vector(7 downto 0);
   type period_t is (TIM1T, TIM8T, TIM64T, TIM1024T);

   signal ram              : ram_t  := ("00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000",
                                        "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000");
   signal period           : period_t := TIM1T;
   
   signal ddra              : std_logic_vector(7 downto 0) := "00000000";
   signal ddrb              : std_logic_vector(7 downto 0) := "00000000";
   signal ora               : std_logic_vector(7 downto 0) := "00000000";
   signal orb               : std_logic_vector(7 downto 0) := "00000000";
   signal pa7_flag          : std_logic := '0';
   signal timer_flag        : std_logic := '0';
   signal pa7_flag_enable   : std_logic := '0';
   signal timer_flag_enable : std_logic := '0';
   signal edge_detect       : std_logic := '0';
   
   signal pa7_clear_need    : std_logic := '0';
   signal pa7_clear_done    : std_logic := '0';
   
   signal timer_clear_need  : std_logic := '0';
   signal timer_clear_done  : std_logic := '0';
   
   signal counter           : std_logic_vector(18 downto 0) := "0000000000000000000";
   
begin
   IRQ_n <= not ((timer_flag and timer_flag_enable) or (pa7_flag and pa7_flag_enable));
   
   -- For all functions, R_W and A are valid on the rising edge of PHI2
   -- D must be stable by the falling edge of PHI2
   
   process(phi2) begin
      if ((phi2'event) and (phi2 = '1')) then                              --! [0]
         if ((res_n = '1') and (CS1 = '1') and (CS2_n = '0')) then         --! [1]
            if (R_W = '1') then                                            --! [2]
               if (RS_n = '0') then                                        --! [3]
                  dataOut <= ram(CONV_INTEGER(addr));
               else                                                        --! [3]
                  if (addr(2) = '0') then                                  --! [4]
                     if (addr(1 downto 0) = "00") then                     --! [5]
                        dataOut <= pa;
                     elsif (addr(1 downto 0) = "01") then                  --! [5]
                        dataOut <= ddra;
                     elsif (addr(1 downto 0) = "10") then                  --! [5]
                        dataOut <= pb;
                     elsif (addr(1 downto 0) = "11") then                  --! [5]
                        dataOut <= ddrb;
                     end if;                                               --! [5]
                  else                                                     --! [4]
                     if (addr(0) = '0') then                               --! [6]
                        timer_clear_need <= not timer_clear_need;
                        if (counter(18) = '1') then                        --! [7]
                           dataOut <= counter(7 downto 0);
                        else                                               --! [7]
                           if (period = TIM1T) then                        --! [8]
                              dataOut <= counter(7 downto 0);
                           elsif (period = TIM8T) then                     --! [8]
                              dataOut <= counter(10 downto 3);
                           elsif (period = TIM64T) then                    --! [8]
                              dataOut <= counter(13 downto 6);
                           elsif (period = TIM1024T) then                  --! [8]
                              dataOut <= counter(17 downto 10);
                           end if;                                         --! [8]
                        end if;                                            --! [7]
                     else                                                  --! [6]
                        dataOut(7) <= timer_flag;
                        dataOut(6) <= pa7_flag;
                        dataOut(5 downto 0) <= "000000";
                        pa7_clear_need <= not pa7_clear_need;
                     end if;                                               --! [6]
                  end if;                                                  --! [4]
               end if;                                                     --! [3]
            else                                                           --! [2]
               dataOut <= "00000000";
            end if;                                                        --! [2]
         else                                                              --! [1]
            dataOut <= "00000000";
         end if;                                                           --! [1]
      end if;                                                              --! [0]
   end process;
   
   process(phi2) begin
      if ((phi2'event) and (phi2 = '0')) then                              --! [9]
         if (edge_detect = pa(7)) then                                     --! [10]
            pa7_flag <= '1';
         end if;                                                           --! [10]
         
         if (counter(18) = '1') then                                       --! [11]
            period <= TIM1T;
            timer_flag <= '1';
         end if;                                                           --! [11]
         
         counter <= counter - "0000000000000000001";
         
         if (pa7_clear_need /= pa7_clear_done) then                        --! [12]
            pa7_clear_done <= pa7_clear_need;
            pa7_flag <= '0';
         end if;                                                           --! [12]
         
         if (timer_clear_need /= timer_clear_done) then                    --! [13]
            timer_clear_done <= timer_clear_need;
            timer_flag <= '0';
         end if;                                                           --! [13]
         
         if ((RES_n = '1') and (CS1 = '1') and (CS2_n = '0')) then         --! [14]
            if (R_W = '0') then                                            --! [15]
               if (RS_n = '0') then                   -- ram               --! [16]
                  ram(CONV_INTEGER(addr)) <= dataIn;
                  --                  COUNTER <= COUNTER - "0000000000000000001";
               else                                                        --! [16]
                  if (addr(2) = '0') then                                  --! [17]
                     if (addr(1 downto 0) = "00") then                     --! [18]
                        pa_out <= dataIn;
                     elsif (addr(1 downto 0) = "01") then                  --! [18]
                        ddra <= dataIn;
                        pa_dir <= dataIn;
                     elsif (addr(1 downto 0) = "10") then                  --! [18]
                        pb_out <= dataIn;
                     elsif (addr(1 downto 0) = "11") then                  --! [18]
                        ddrb <= dataIn;
                        pb_dir <= dataIn;
                     end if;                                               --! [18]
                     --                    COUNTER <= COUNTER - "0000000000000000001";
                  else                                                     --! [17]
                     if (addr(4) = '1') then                               --! [19]
                        if (addr(1 downto 0) = "00") then                  --! [20]
                           period <= TIM1T;
                           counter(18 downto 8) <= "00000000000";
                           counter(7 downto 0) <= dataIn;
                           timer_flag <= '0';
                        elsif (addr(1 downto 0) = "01") then               --! [20]
                           period <= TIM8T;
                           counter(18 downto 11) <= "00000000";
                           counter(10 downto 3) <= dataIn;
                           counter(2 downto 0) <= "000";
                           timer_flag <= '0';
                        elsif (addr(1 downto 0) = "10") then               --! [20]
                           period <= TIM64T;
                           counter(18 downto 14) <= "00000";
                           counter(13 downto 6) <= dataIn;
                           counter(5 downto 0) <= "000000";
                           timer_flag <= '0';
                        else                                               --! [20]
                           period <= TIM1024T;
                           counter(18) <= '0';
                           counter(17 downto 10) <= dataIn;
                           counter(9 downto 0) <= "0000000000";
                           timer_flag <= '0';
                        end if;                                            --! [20]
                        timer_flag_enable <= addr(3);
                     else                                                  --! [19]
                        if (addr(2) = '1') then                            --! [21]
                           pa7_flag_enable <= addr(1);
                           edge_detect <= addr(0);
                        end if;                                            --! [21]
                        --                      COUNTER <= COUNTER - "0000000000000000001";
                     end if;                                               --! [19]
                  end if;                                                  --! [17]
               end if;                                                     --! [16]
            else                                                           --! [15]
               if ((addr(2) = '1') and (addr(0) = '0')) then               --! [22]
                  timer_flag_enable <= addr(3);
               end if;                                                     --! [22]
               --             COUNTER <= COUNTER - "0000000000000000001";
            end if;                                                        --! [15]
         else                                                              --! [14]
            if (RES_n = '0') then                                            --! [23]
               ora               <= "00000000";
               orb               <= "00000000";
               ddra              <= "00000000";
               ddrb              <= "00000000";
               pa7_flag          <= '0';
               timer_flag        <= '0';
               pa7_flag_enable   <= '0';
               timer_flag_enable <= '0';
               edge_detect       <= '0';
               period            <= TIM1T;
               counter           <= "0000000000000000000";
               --            else
               --               COUNTER <= COUNTER - "0000000000000000001";
            end if;                                                        --! [23]
         end if;                                                           --! [14]
      end if;                                                              --! [9]
   end process;
   
   -- I/O port handling
--   process(ora, ddra, orb, ddrb) begin
--      for i in 7 downto 0 loop
--         if (ddra(i) = '1') then                                           --! [24]
--            pa_out(i) <= ora(i);
--         end if;                                                           --! [24]
--         if (ddrb(i) = '1') then                                           --! [25]
--            pb_out(i) <= orb(i);
--         end if;                                                           --! [25]
--      end loop;
--   end process;
end;