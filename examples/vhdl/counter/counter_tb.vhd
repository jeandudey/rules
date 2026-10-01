library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library counter;

entity counter_tb is
  generic (
    CYCLES : natural := 20
  );
end entity;

architecture sim of counter_tb is
  constant WIDTH : positive := 4;
  signal clk     : std_logic := '0';
  signal reset   : std_logic := '1';
  signal count   : unsigned(WIDTH - 1 downto 0);
begin
  dut : entity counter.counter
    generic map (WIDTH => WIDTH)
    port map (clk => clk, reset => reset, count => count);

  process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
    reset <= '0';
    for cycle in 1 to CYCLES loop
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
      assert count = to_unsigned(cycle mod 2 ** WIDTH, WIDTH)
        report "count is " & integer'image(to_integer(count)) & ", expected " & integer'image(cycle mod 2 ** WIDTH)
        severity error;
    end loop;
    report "counter_tb passed";
    wait;
  end process;
end architecture;
