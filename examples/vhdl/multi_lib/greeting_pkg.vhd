package greeting_pkg is
  function greeting(name : string) return string;
end package;

package body greeting_pkg is
  function greeting(name : string) return string is
  begin
    return "Hello, " & name & "!";
  end function;
end package body;
