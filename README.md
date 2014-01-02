## Puissant
### Reactive Mail

Puissant can be said to be the backend framework for DotMail, and the development of both is tied tightly together.  

## Reactivity

Puissant is a high-level imperative interface over a reactive core that deals with everything from database management to email requests for DotMail.  While that does mean that applications have a very limited access to the reactive internals, it also means the framework can one day be liberated from DotMail and applied to many applications and situations.  This means APIs that are exposed by the framework tend to be marked as returning `void` or taking a block rather than returning `RACSignal *`. 

The framework internals depend heavily on [Reactive Cocoa](https://github.com/ReactiveCocoa/ReactiveCocoa), and often change dramatically to reflect new APIs in ReactiveCocoa.  Reliance on a particular undocumented behavior is discouraged doubly so because of the state of flux this can leave us in at times.

## Can I use this outside of DotMail?

Puissant acts as a backend framework for the DotMail, and often includes DotMail-specific functions and members.  As such, it is suitable only for use in DotMail app.  While this is strictly a guideline the code is open source, and therefore, we encourage reuse.  Puissant is designed to be as modular as possible, so pulling chunks out of it is probably the best option until the framework is more general. 