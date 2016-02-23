import Foundation

@objc public class Watchdog: NSObject {
    
    private var threshold: Double
    private var pingThread: PingThread
    
    /**
     Class for logging excessive blocking on the main thread.
     
     @param threshold number of seconds that must pass to consider the main thread blocked.
     
     @param strictMode boolean value that stops the execution whenever the threshold is reached.
     
     @param logger optional callback to log message.
     
     */
    public init(threshold: Double = 0.4, strictMode: Bool = false, logger: ((String) -> Void)? = nil) {
        
        self.threshold = threshold
        self.pingThread = PingThread(threshold: threshold) {
            
            let message = "👮 Main thread was blocked for "
                + String(format:"%.2f", threshold) + "s 👮"
            
            if strictMode {
                assertionFailure()
            } else {
                if let logger = logger {
                    logger(message)
                } else {
                    NSLog("%@", message)
                }
            }
        }
        
        self.pingThread.start()
        super.init()
    }
    
    deinit {
        pingThread.cancel()
        
    }
}

private class PingThread: NSThread {
    var pingTaskIsRunning = false
    var semaphore = dispatch_semaphore_create(0)
    var threshold: Double
    var handler: () -> Void
    
    init(threshold: Double, handler: () -> Void) {
        self.threshold = threshold
        self.handler = handler
    }
    
    override func main() {
        while !self.cancelled {
            
            pingTaskIsRunning = true
            dispatch_async(dispatch_get_main_queue()) {
                self.pingTaskIsRunning = false
                dispatch_semaphore_signal(self.semaphore)
            }
            
            NSThread.sleepForTimeInterval(threshold)
            if pingTaskIsRunning {
                self.handler()
            }
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        }
    }
}
