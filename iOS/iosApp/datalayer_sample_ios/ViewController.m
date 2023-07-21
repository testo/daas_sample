#import "ViewController.h"

#import <datalayer/datalayer.h>

#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *textViewLog;

@property (nonatomic, strong) NSMutableArray<DatalayerProbe>* probes;
@property (nonatomic, strong) DatalayerProbeFactory* probeFactory;

@end

@implementation ViewController

- (void)addLineToTextViewLog:(NSString*) logMsg prefixTimestamp: (BOOL) prefixTimestamp {
  
  NSDate *now = [NSDate date];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"HH:mm:ss"];
  
  NSString *newString;
  
  if (prefixTimestamp)
  {
    NSString *timestamp = [formatter stringFromDate:now];
    newString = [NSString stringWithFormat:@"%@: %@\n", timestamp, logMsg];
  }
  else
  {
    newString = [NSString stringWithFormat:@"%@\n", logMsg];
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    // Perform UI updates on the main thread
    NSString *existingText = self.textViewLog.text;
    NSString *updatedText = [existingText stringByAppendingString:newString];
    self.textViewLog.text = updatedText;
    
    NSLog(@"%@", updatedText);
    
    NSRange range = NSMakeRange(updatedText.length - 1, 1);
    [self.textViewLog scrollRangeToVisible:range];
  });
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  _probes = [NSMutableArray<DatalayerProbe> array];
  _probeFactory = [[DatalayerProbeFactory alloc] init];
  
  CBManagerAuthorization btAuthorization = [CBManager authorization];
  NSString* btAuthorizationString;
  switch (btAuthorization)
  {
    case CBManagerAuthorizationAllowedAlways:
      btAuthorizationString = @"CBManagerAuthorizationAllowedAlways";
      break;
    case CBManagerAuthorizationDenied:
      btAuthorizationString = @"CBManagerAuthorizationDenied";
      break;
    case CBManagerAuthorizationNotDetermined:
      btAuthorizationString = @"CBManagerAuthorizationNotDetermined";
      break;
    case CBManagerAuthorizationRestricted:
      btAuthorizationString = @"CBManagerAuthorizationRestricted";
      break;
  }
  NSLog(@"btAuthorizationString %@", btAuthorizationString);
  [self startScan];
}

- (void)startScan
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self->_probeFactory startBtScan];
  });
}

- (IBAction)getDevicesButtonClicked:(id)sender
{
  
  [self addLineToTextViewLog:@"getDevicesButtonClicked" prefixTimestamp:true];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSArray<DatalayerBluetoothInfo*>* connectableDevices = [self->_probeFactory getConnectableDevices];
    for (size_t i = 0; i < [connectableDevices count]; i++) {
      NSString *logMsg = [NSString stringWithFormat:@"detected device: %@", connectableDevices[i]];
      [self addLineToTextViewLog:logMsg prefixTimestamp:false];
    }
  });
}

- (IBAction)connectButtonClicked:(id)sender
{
  [self addLineToTextViewLog:@"connectButtonClicked" prefixTimestamp:true];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSArray<DatalayerBluetoothInfo*>* connectableDevices = [self->_probeFactory getConnectableDevices];
    for (DatalayerBluetoothInfo* device in connectableDevices)
    {
      DatalayerProbeType* probeType = device.probeType;
      
      // convert serial to uint64_t
      NSScanner *scanner = [NSScanner scannerWithString:device.serialNo];
      uint64_t serial = 0;
      [scanner scanUnsignedLongLong:&serial];
      
      NSString *logMsg = [NSString stringWithFormat:@"probeType %@, serial %llu", probeType.value, serial];
      [self addLineToTextViewLog:logMsg prefixTimestamp:false];
      
      id<DatalayerProbe> probe = [self->_probeFactory createDevice:device];
      if ([probe isDeviceAvailable])
      {
        @synchronized (self->_probes) {
          [self->_probes addObject:probe];
        }
        NSString *batteryMsg = [NSString stringWithFormat:@"battery %f", [probe getBatteryLevel]];
        [self addLineToTextViewLog:batteryMsg prefixTimestamp:false];
        
        if (probeType == DatalayerProbeType.mfHandle || probeType == DatalayerProbeType.qsrHandle)
        {
          [probe subscribeNotificationMeasType:DatalayerMeasType.temperature notifyFunction:^(DatalayerMeasData * measDataWrapper) {
            DatalayerAbstractProbeValue* probeValue = [measDataWrapper probeValue];
            NSString *temperatureMsg = [NSString stringWithFormat:@"notifyFunction temperature value: %f precision: %i unit: %@ measType: %@", [probeValue value], [probeValue precision], [measDataWrapper physicalUnit], [measDataWrapper measType]];
            [self addLineToTextViewLog:temperatureMsg prefixTimestamp:false];
            
          }];
          [probe subscribeNotificationMeasType:DatalayerMeasType.oilQuality notifyFunction:^(DatalayerMeasData * measDataWrapper) {
            DatalayerAbstractProbeValue* probeValue = [measDataWrapper probeValue];
            NSString *oilMsg = [NSString stringWithFormat:@"notifyFunction oilQuality value: %f precision: %i unit: %@ measType: %@", [probeValue value], [probeValue precision], [measDataWrapper physicalUnit], [measDataWrapper measType]];
            [self addLineToTextViewLog:oilMsg prefixTimestamp:false];
          }];
        }
        else if (probeType == DatalayerProbeType.t104IrBt)
        {
          [probe subscribeNotificationMeasType:DatalayerMeasType.plungeTemperature notifyFunction:^(DatalayerMeasData * measDataWrapper) {
            DatalayerAbstractProbeValue* probeValue = [measDataWrapper probeValue];
            NSString *plungeTempMsg = [NSString stringWithFormat:@"notifyFunction plungeTemperature value: %f precision: %i unit: %@ measType: %@", [probeValue value], [probeValue precision], [measDataWrapper physicalUnit], [measDataWrapper measType]];
            [self addLineToTextViewLog:plungeTempMsg prefixTimestamp:false];
          }];
          [probe subscribeNotificationMeasType:DatalayerMeasType.surfaceTemperature notifyFunction:^(DatalayerMeasData * measDataWrapper) {
            DatalayerAbstractProbeValue* probeValue = [measDataWrapper probeValue];
            NSString *surfaceTempMsg = [NSString stringWithFormat:@"notifyFunction surfaceTemperature value: %f precision: %i unit: %@ measType: %@", [probeValue value], [probeValue precision], [measDataWrapper physicalUnit], [measDataWrapper measType]];
            [self addLineToTextViewLog:surfaceTempMsg prefixTimestamp:false];
          }];
        }
      }
      else
      {
        NSString *plungeTempMsg = [NSString stringWithFormat:@"error: could not connect to probe %@", device.serialNo];
        [self addLineToTextViewLog:plungeTempMsg prefixTimestamp:false];
      }
    }
  });
}

- (IBAction)getBatteryButtonClicked:(id)sender
{
  [self addLineToTextViewLog:@"getBatteryButtonClicked" prefixTimestamp:true];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @synchronized (self->_probes) {
      for (int64_t i = self->_probes.count - 1; i >= 0; --i)
      {
        DatalayerBase<DatalayerProbe>* probe = self->_probes[i];
        if ([probe isDeviceAvailable])
        {
          NSString *logMsg = [NSString stringWithFormat:@"%llu %f", [self->_probes[i] getSerial], [self->_probes[i] getBatteryLevel]];
          [self addLineToTextViewLog:logMsg prefixTimestamp:false];
        }
        else
        {
          NSString *logMsg = [NSString stringWithFormat:@"remove disconnected device: %llu", [self->_probes[i] getSerial]];
          [self addLineToTextViewLog:logMsg prefixTimestamp:false];
          [self->_probes removeObjectAtIndex:i];
        }
      }
    }
  });
}

- (IBAction)disconnectButtonClicked:(id)sender {
  [self addLineToTextViewLog:@"disconnectButtonClicked" prefixTimestamp:true];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @synchronized (self->_probes) {
      for (int64_t i = 0; i < self->_probes.count; ++i)
      {
        [self->_probes[i] disconnect];
      }
      [self->_probes removeAllObjects];
    }
  });
}

@end
