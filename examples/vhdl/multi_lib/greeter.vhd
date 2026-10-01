library util;
use util.greeting_pkg.all;

entity greeter is
  generic (
    NAME : string := "world"
  );
end entity;

architecture behavioral of greeter is
begin
  process
  begin
    report greeting(NAME);
    wait;
  end process;
end architecture;
