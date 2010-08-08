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
