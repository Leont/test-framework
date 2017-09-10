unit module Test::Framework;

role Context {
	has CallFrame:D $.frame is required handles <file line package>;
	method todo() {
		return $.frame.my<$TODO>
	}
	method as-string() { ... }
	method as-pairs() { ... }
}

class CodeContext does Context {
	method as-string() {
		return "at $.file line $.line";
	}
	method as-pairs() {
		return (:$.file, :$.line);
	}
}

role Event {
}

role Plan does Event {
}
class TestPlan does Plan {
	has Int:D $.tests is required;
}

class SkipAll does Plan {
	has Str $.reason;
}
class DoneTesting does Plan {
}


role Result {
}
role Passing does Result {
}
role Described does Result {
	has Str:D $.description is default('');
}
role Explained does Result {
	has Str:D $.explanation is default('');
}
role Diagnostics does Result {
	has Pair @.diagnostics is default(());
}
class Ok does Passing does Described {
}
class NotOk does Result does Described does Diagnostics {
}
class Todo does Passing does Described does Explained {
	has Bool:D $.actual is default(False);
}
class Skip does Passing does Explained {
}

role Test does Event {
	method passed() {
		return $.result ~~ Passing;
	}
	has Result:D $.result is required;
	has Context:D $.context is required;
}

class SingleTest does Test {
}

class SubTest does Test {
	has Event @.events;
	method BUILDALL(|) {
		callsame;
		if $!result !~~ Todo {
			my $expected = $.result ~~ any(Ok,Skip);
			my $got = ?all(@!events.grep(Test)».passed);
			die "Something fishy is going on $!result.perl() @!events.perl()" if $got !== $expected;
		}
		return self;
	}
}

role Comment does Event {
	has Str:D $.description is required;
}

class Note does Comment {
}

class Warning does Comment {
}

role Listener {
	method accept(Event $) { ... }
	method finalize() { ... }
}
