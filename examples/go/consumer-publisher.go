package main

import (
  "fmt"
  "runtime"
)

func producer(c chan int, N int, s chan bool) {
  for i := 0; i < N; i++ {
    fmt.Printf("producer: %d\n", i)
    c <- i
  }
  s <- true
}

func consumer(c chan int, N int, s chan bool) {
  for i := 0; i < N; i++ {
    fmt.Printf("consumer got: %d\n", <- c)
  }
  s <- true
}

func main() {
  runtime.GOMAXPROCS(2)

  c := make(chan int)
  s := make(chan bool)

  go producer(c, 10, s)
  go consumer(c, 10, s)

  <- s
  <- s
}
