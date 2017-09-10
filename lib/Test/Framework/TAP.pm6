use Test::Framework;

unit class Test::Framework::TAP does Test::Framework::Listener;

subset Handle of Any where { ?.can(all(<say flush>)) };
has Handle $.out is required;
subset TapVersion of Int where * >= 12;
has TapVersion:D $.version = 12;
has $!counter = 0;

method BUILDALL(|) {
	callsame;
	if $!version > 12 {
		$!out.say: "TAP version $!version";
	}
	self;
}

method accept(Test::Framework::Event $event) {
	$!out.say: to-tap($event, $!counter);
}

method finalize() {
	$!out.flush;
}

my proto to-tap(Test::Framework::Event $, $counter is rw) { * }
multi to-tap(Test::Framework::TestPlan $plan, $) {
	return "1..{ $plan.tests }";
}
multi to-tap(Test::Framework::SkipAll $skipall, $) {
	my $explanation = $skipall.explanation.subst(/\n .*/, '');
	return "1..0 #SKIP $explanation";
}
multi to-tap(Test::Framework::DoneTesting $, $counter) {
	return "1..$counter";
}

my sub test-to-line($result, $number, $context) {
	my $description = $result.description.subst(/\n .*/, '').subst(/(<[\\\#]>)/, -> $char { "\\$char" });
	given $result {
		when Test::Framework::Ok {
			return "ok $number - $description";
		}
		when Test::Framework::NotOk {
			my $line = "not ok $number - $description";
			my @pairs = (|$result.diagnostics, |$context.as-pairs);
			if @pairs {
				# XXX this needs newline escaping
				my @diagnostics = ('---', |@pairs.map({ "{.key}: {.value}" }), '...').map(*.indent(2));
				return ($line, |@diagnostics).join("\n");
			}
			else {
				return $line;
			}
		}
		when Test::Framework::Todo {
			my $ok = $result.actual ?? 'ok' !! 'not ok';
			return "$ok $number - $description # TODO { $result.explanation }";
		}
		when Test::Framework::Skip {
			return "ok $number - $description # SKIP { $result.explanation }";
		}
		when Version {
		}
	}
}

multi to-tap(Test::Framework::SingleTest $test, $counter is rw ) {
	return test-to-line($test.result, ++$counter, $test.context);
}

multi to-tap(Test::Framework::Comment $comment, $) {
	return $comment.description.split("\n").map({ "# $_" }).join("\n");
}

multi to-tap(Test::Framework::SubTest $subtest, $counter is rw ) {
	my $subcounter = 0;
	my @sub-tests = $subtest.events.map({ to-tap($_, $subcounter) }).map(*.indent(4));
	my $conclusion = test-to-line($subtest.result, ++$counter, $subtest.context);
	return (|@sub-tests, $conclusion).join("\n");
}
