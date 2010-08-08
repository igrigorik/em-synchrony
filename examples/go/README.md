# CSP Experiments with Ruby

Partly an exercise to help myself wrap my head around Go's concurrency, partly an experiment to see how much of the syntax & behavior of Go's CSP model can be modelled in Ruby... As it turns out, it's not hard to almost replicate the look and feel.

Note: none of the Ruby examples actually give you the parallelism of Go.

## Notes
 * Instead of explicitly using locks to mediate access to shared data, Go encourages the use of channels to pass references to data between goroutines.

 * Channels combine communication — the exchange of a value—with synchronization — guaranteeing that two calculations (goroutines) are in a known state.

go.rb implements an (un)bounded Channel interface, and with some help from Fibers & Ruby 1.9, we can also implement the goroutine look and feel pretty easily. In fact, with CSP semantics, its not hard to imagine a MVM (multi-VM) Ruby where each VM still has a GIL, but where data sharing is done via communication of references between VM's.

## Simple channel example in Go

    package main

    import (
      "fmt"
      "time"
    )

    func main() {
      c := make(chan string)

      go func() {
        time.Sleep(1)
        c <- "go go go sleep 1!"
       }()

       fmt.Printf("%v\n", <-c)  // Wait for goroutine to finish
    }

## Equivalent in Ruby

    require 'go'

    EM.synchrony do
      c = Channel.new

      go {
        sleep(1)
        c << 'go go go sleep 1!'
      }

      puts c.pop

      EM.stop
    end

