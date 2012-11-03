# Stack tracer for JRuby threads with JStack

First let's look at using JStack for a basic Java app, then look at the same app written in Ruby and running on JRuby.

Example taken from http://www.herongyang.com/Java-Tools/jstack-JVM-Thread-Dump-Stack-Strace.html

## Java and JStack

``` java
/**
 * LongSleep.java
 * Copyright (c) 2008 by Dr. Herong Yang, http://www.herongyang.com/
 */
class LongSleep {
   public static void main(String[] a) {
      Runtime rt = Runtime.getRuntime();
      System.out.println(" Free memory: " + rt.freeMemory());
      System.out.println("Total memory: " + rt.totalMemory());
      try {Thread.sleep(1000*60*60);} 
      catch (InterruptedException e) {}
   }
}
```

Then run:

```
$ javac LongSleep.java
$ java LongSleep
 Free memory: 83588920
Total memory: 85000192
* pauses unexplainably!! *
```

Find all running Java processes in another terminal:

```
$ jps
47521 Jps
30447 LongSleep
```

Now we can view all the threads of our `LongSleep` application. We see that one of the threads is in a `TIMED_WAITING` state and it came from our application.

```
$ jstack -l 30447
...
"main" prio=5 tid=7fdec4000800 nid=0x110535000 waiting on condition [110534000]
   java.lang.Thread.State: TIMED_WAITING (sleeping)
  at java.lang.Thread.sleep(Native Method)
  at LongSleep.main(LongSleep.java:10)

   Locked ownable synchronizers:
   - None
```

Ahh, its sleeping. Great, we could now go and fix that in `LongSleep.main(LongSleep.java:10)`.

Awesome.

## JRuby and JStack

Let's rewrite LongSleep as a Ruby app for JRuby.

``` ruby
# long_sleep.rb

require 'java'
class RuntimeView
  def display
    rt = java.lang.Runtime.getRuntime
    puts " Free memory: #{rt.freeMemory}"
    puts "Total memory: #{rt.totalMemory}"
    sleep 1000 * 60 * 60
  end
end

RuntimeView.new.display
```

Run it:

```
$ jruby long_sleep.rb
 Free memory: 73802224
Total memory: 85000192
```

Find the process and look for our stuck thread:

```
$ jps
47521 Jps
30447 LongSleep

$ jstack -l 30447
...
"main" prio=5 tid=7fcfe3000800 nid=0x101bb4000 in Object.wait() [101bb2000]
   java.lang.Thread.State: TIMED_WAITING (on object monitor)
  at java.lang.Object.wait(Native Method)
  - waiting on <7df9e8d60> (a org.jruby.RubyThread)
  at org.jruby.RubyThread.sleep(RubyThread.java:864)
  - locked <7df9e8d60> (a org.jruby.RubyThread)
  - locked <7df9e8d60> (a org.jruby.RubyThread)
  at org.jruby.RubyKernel.sleep(RubyKernel.java:792)
  at org.jruby.RubyKernel$INVOKER$s$0$1$sleep.call(RubyKernel$INVOKER$s$0$1$sleep.gen)
  at org.jruby.internal.runtime.methods.JavaMethod$JavaMethodN.call(JavaMethod.java:642)
  at org.jruby.internal.runtime.methods.DynamicMethod.call(DynamicMethod.java:204)
  at org.jruby.runtime.callsite.CachingCallSite.cacheAndCall(CachingCallSite.java:326)
  at org.jruby.runtime.callsite.CachingCallSite.call(CachingCallSite.java:170)
  at long_sleep.method__1$RUBY$display(long_sleep.rb:9)
  at long_sleep$method__1$RUBY$display.call(long_sleep$method__1$RUBY$display)
  at long_sleep$method__1$RUBY$display.call(long_sleep$method__1$RUBY$display)
  at org.jruby.runtime.callsite.CachingCallSite.cacheAndCall(CachingCallSite.java:306)
  at org.jruby.runtime.callsite.CachingCallSite.call(CachingCallSite.java:136)
  at long_sleep.__file__(long_sleep.rb:13)
  at long_sleep.load(long_sleep.rb)
  at org.jruby.Ruby.runScript(Ruby.java:770)
  at org.jruby.Ruby.runScript(Ruby.java:763)
  at org.jruby.Ruby.runNormally(Ruby.java:640)
  at org.jruby.Ruby.runFromMain(Ruby.java:489)
  at org.jruby.Main.doRunFromMain(Main.java:375)
  at org.jruby.Main.internalRun(Main.java:264)
  at org.jruby.Main.run(Main.java:230)
  at org.jruby.Main.run(Main.java:214)
  at org.jruby.Main.main(Main.java:194)

   Locked ownable synchronizers:
	- None
```

Looking through the list of threads (not shown above) we again find this thread in a `TIMED_WAITING` state. The first thing I notice is that the JRuby stack trace is a lot longer than the pure Java one.

After finding the `TIMED_WAITING` state thread, it is clear that this thread is `locked` by `RubyKernel.sleep`.

Looking down the stack trace, it is not as clear, but you can see that my application is involved at `long_sleep.rb:9`:

```
long_sleep.method__1$RUBY$display(long_sleep.rb:9)
```

Slightly hard to read, but the blocking occurs within a `#display` method (on an unspecified class?) on line 9 in `long_sleep.rb`.

Again, wonderful. I can now start debugging!

I definitely look forward to using jstack in future as part of debugging applications in development and in production.
