# Asink
Experiments in iterating on async primitives for Roblox Lua projects. It intends to explore a design space similar to Promises, but in a slightly different direction.

**Asink is a very early work in progress, but feedback is welcome!**

## Overview
This project takes inspiration from the Rust async ecosystem, which believes in composing simple types together to get interesting behaviors.

A type you might see from this library could be `Future<Result<Cancelable<string>, string>>`. This looks intimidating, but once you get used to it, it clearly encodes all the things that can go wrong in our function.

It says:

* `Future` (our function is async)
	* ...returning a `Result` (our function can fail)
		* ...containing a `string` on success (like the body of an HTTP response)
		* ...and containing a different `string` on failure (like an error message)

Asink forces consuming code to explicitly handle failure, which can be as simple as throwing an error. This is in contrast to yielding+exceptions and promises in that failure must be acknowledged.

For a semi-practical example, see [the HTTP example](examples/http)

## Types
Asink currently exposes:

### `Result<T, E>`
Modeled after Rust's [type of the same name](https://doc.rust-lang.org/stable/std/result/enum.Result.html).

* `Result.new(success, value) => Result`
* `Result.ok(value: T) => Result`
* `Result.error(err: E) => Result`
* `Result.isResult(value: any) => bool`
* `Result:unpack() => (true, T) | (false, E)`
* `Result:unwrapOrDie() => T`
* `Result:unwrapErrorOrDie() => T`
* `Result:isOk() => bool`
* `Result:isError() => bool`
* `Result:map(f: T => U) => Result<U, E>`
* `Result:mapError(f: E => F) => Result<T, F>`
* `Result:andThen(f: T => Result<U, E>) => Result<U, E>`
* `Result:orElse(f: E => Result<T, F>) => Result<T, F>`

### `Future<T>`
Loosely modeled after Rust's [type of the same name](https://doc.rust-lang.org/stable/std/future/trait.Future.html).

* `Future.new() => Future, resolveFn`
* `Future.resolved(value: T) => Future`
* `Future.isFuture(value: any) => bool`
* `Future.all(futures: Future[]) => Future`
* `Future:isResolved() => bool`
* `Future:unwrapOrDie() => T`
* `Future:await() => yields T`
* `Future:map(f: T => U) => Future<U>`
* `Future:andThen(f: T => Future<U>) => Future<U>`

### `Cancelable<T>`

* `Cancelable.completed(value: T) => Cancelable`
* `Cancelable.canceled() => Cancelable`
* `Cancelable.isCancelable(value: any) => bool`
* `Cancelable:unpack() => (true, T) | false`
* `Cancelable:unwrapOrDie() => T`
* `Cancelable:isCompleted() => bool`
* `Cancelable:isCanceled() => bool`
* `Cancelable:map(f: T => U) => Cancelable<U>`
* `Cancelable:andThen(f: T => Cancelable<U>) => Cancelable<U>`

### `Runtime`
Currently non-functional.

* `Runtime.addFutureRejectionHandler(fn)`

## Examples
To build and run an example, use:

```bash
rojo build examples/http -o Http.rbxlx
start Http.rbxlx # use 'open' on macOS
```

## License
Available under the MIT license. Details are available in [LICENSE.txt](LICENSE.txt) or at <https://opensource.org/licenses/MIT>.