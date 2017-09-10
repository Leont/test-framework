unit class Test::Framework::Hub;

use Test::Framework;

has Test::Framework::Listener:D $!listener is required;

my class MainListener does Test::Framework::Listener {
	has Test::Framework::Listener $!formatter;
	enum Seen <Nope Before After>;
	has $!plan-seen = Nope;
	has $!tests-expected;
	has $!tests-seen = 0;
	has $!tests-failed = 0;
	submethod TWEAK (:$!formatter) { }
	proto method accept(Test::Framework::Event $event) {
		{*}
		$!formatter.accept($event)
	}
	multi method accept(Test::Framework::Test $test) {
		$!tests-seen++;
		$!tests-failed++ if !$test.passed;
		if $!plan-seen === After {
			my $description = 'Seen plan in the middle of tests';
			self.accept(Test::Framework::Warning.new(:$description));
		}
	}
	multi method accept(Test::Framework::Plan $plan) {
		if $!plan-seen !== Nope {
			die 'Can only plan once';
		}
		else {
			$!plan-seen = $!tests-seen > 0 ?? After !! Before;
		}
	}
	multi method accept(Test::Framework::TestPlan $plan) {
		callsame;
		$!tests-expected = $plan.tests;
	}
	multi method accept(Test::Framework::SkipAll $plan) {
		callsame;
		$!tests-expected = 0;
	}
	multi method accept(Test::Framework::DoneTesting $done) {
		callsame;
		$!tests-expected = $!tests-seen;
	}
	multi method accept(Test::Framework::Comment $) {
	}
	method finalize() {
		if $!tests-expected.defined.not {
			$!formatter.accept(Test::Framework::Warning.new(:description('No plan seen')));
		}
		elsif $!tests-seen != $!tests-expected {
			$!formatter.accept(Test::Framework::Warning.new(:description("Expected $!tests-expected tests but seen $!tests-seen")));
		}
		elsif $!tests-failed > 0 {
			$!formatter.accept(Test::Framework::Warning.new(:description("Looks like you failed $!tests-failed test of $!tests-seen.")));
		}
		$!formatter.finalize;
	}
	method exit-value() {
		my $failure = $!tests-failed || ($!tests-seen == $!tests-expected // Inf ?? 0 !! 254);
		return min($failure, 254);
	}
}

submethod BUILD(Test::Framework::Listener:D :$formatter!) {
	 $!listener = MainListener.new(:$formatter);
}

my sub test-result(:$success, :$todo, :$description, Pair :@diagnostics) {
	if $todo.defined {
		return Test::Framework::Todo.new(:actual($success), :$description, :explanation(~$todo));
	}
	elsif $success {
		return Test::Framework::Ok.new(:$description);
	}
	else {
		return Test::Framework::NotOk.new(:$description, :@diagnostics);
	}
}

method test(Bool $success, Str $description, Int :$offset = 1, Test::Framework::Context :$context = Test::Framework::CodeContext.new(:frame(callframe($offset + 2))), :$todo = $context.todo, Pair :@diagnostics) {
	my $result = test-result(:$success, :$description, :$todo, :@diagnostics);
	$!listener.accept(Test::Framework::SingleTest.new(:$result, :$context));
	if $success && $result ~~ Test::Framework::Todo {
		self.note("Passing todo $description");
	}
}

method skip(Str $reason) {
	$!listener.accept(Test::Framework::SingleTest(:result(Test::Framework::Skip), :$reason));
}

class SubTestListener does Test::Framework::Listener {
	has Test::Framework::Event @.events;
	method accept(Test::Framework::Event $event) {
		@!events.push: $event;
	}
	method finalize() {
		@!events.push: Test::Framework::DoneTesting.new if @!events.grep(Test::Framework::Plan) == 0;
	}
	method to-event(:$listener, :$description, :$context, :$todo, Pair :@diagnostics) {
		my $success = ?all(@!events.grep(Test::Framework::Test)».passed);
		my $result = test-result(:$success, :$description, :$todo, :@diagnostics);
		$listener.accept(Test::Framework::SubTest.new(:$result, :$context, :@!events));
		if $success && $result ~~ Test::Framework::Todo {
			$listener.accept(Test::Framework::Warning(:description("Passing todo $description")));
		}
	}
}

method subtest(Str $description, &callback, Int :$offset = 1, Test::Framework::Context :$context = Test::Framework::CodeContext.new(:frame(callframe($offset + 2))), :$todo = $context.todo, Pair :@diagnostics) {
	my $subtest-listener = SubTestListener.new;
	$!listener.accept(Test::Framework::Note.new(:description("Subtest: $description")));
	self.with-listener($subtest-listener, &callback);
	$subtest-listener.finalize;
	$subtest-listener.to-event(:$!listener, :$description, :$context, :$todo, :@diagnostics);
}

method plan(Int $tests) {
	$!listener.accept(Test::Framework::Plan(:$tests));
}
method skip-all(Str $reason) {
	$!listener.accept(Test::Framework::SkipAll(:$reason));
}

multi method done-testing() {
	$!listener.accept(Test::Framework::DoneTesting);
}

multi method done-testing(Int $tests) {
	$!listener.accept(Test::Framework::Plan(:$tests));
}

method note(Str $comment) {
	$!listener.accept(Test::Framework::Note(:$comment));
}
method warning(Str $comment) {
	$!listener.accept(Test::Framework::Warning(:$comment));
}

method finalize() {
	$!listener.finalize;
}
method with-listener(Test::Framework::Listener $listener, &callback) {
	temp $!listener = $listener;
	callback();
}
