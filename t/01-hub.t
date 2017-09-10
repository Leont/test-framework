use v6;

use Test::Framework::Hub;
use Test::Framework::TAP;

my $counter = 0;
sub is($got, $expected, $description = '') {
	my $ok = $got eq $expected ?? 'ok' !! 'not ok';
	say "$ok { ++$counter } - $description";
}
sub done-testing() { say "1..$counter" };

class Capturing {
	has Str $.capture;
	method say ($output) {
		$!capture ~= $output ~ "\n";
	}
	method flush() {}
}

my ($subtest-line, $test-line);
my $file = $?FILE.IO.relative;

sub test($todo) {
	my $out = Capturing.new;
	my $formatter = Test::Framework::TAP.new(:$out);
	my $hub = Test::Framework::Hub.new(:$formatter);
	$hub.test(True, 'HERE', :offset(0));
	my $TODO = $todo;
	$hub.subtest("Foo", { INIT { $test-line = $?LINE }
		$hub.test(True, 'THERE', :offset(0));
		$hub.test(False, 'WHERE', :offset(0)); INIT { $subtest-line = $?LINE }
	}, :offset(0));
	$hub.done-testing;
	$hub.finalize;

	return $out.capture;
}

my $expected1 = qq:heredoc/END/;
ok 1 - HERE
# Subtest: Foo
    ok 1 - THERE
    not ok 2 - WHERE
      ---
      file: $file
      line: $subtest-line
      ...
    1..2
not ok 2 - Foo # TODO Quz
1..2
END

is(test("Quz"), $expected1, 'Output with TODO is as expected');

my $expected2 = qq:heredoc/END/;
ok 1 - HERE
# Subtest: Foo
    ok 1 - THERE
    not ok 2 - WHERE
      ---
      file: $file
      line: $subtest-line
      ...
    1..2
not ok 2 - Foo
  ---
  file: $file
  line: $test-line
  ...
1..2
# Looks like you failed 1 test of 2.
END

is(test(Str), $expected2, 'Output without TODO is as expected');
done-testing;
