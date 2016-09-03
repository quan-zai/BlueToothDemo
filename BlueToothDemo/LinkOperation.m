//
//  LinkOperation.m
//  Weinei-iPhone
//
//  Created by 徐正权 on 16/3/25.
//  Copyright © 2016年 cml. All rights reserved.
//

#import "LinkOperation.h"

// Classes
//#import "CommandCode.h"
//#import "AnalysisCommandCode.h"

/**
 需要注明，下面的UUID是我的蓝牙设备中的Service和Characteristic的UUID，要注意根据自己的蓝牙
 设备来替换
 */

// 蓝牙设备提供的服务的UUID
#define kCGMServiceTwoUUID        @"0000FFF0-0000-1000-8000-00805F9B34FB"

// 蓝牙设备提供的写入特性
#define kCGMCharacteristicOneUUID @"0000FFF1-0000-1000-8000-00805F9B34FB"

// 蓝牙设备提供的notify特性
#define kCGMCharacteristicTwoUUID @"0000FFF2-0000-1000-8000-00805F9B34FB"

@interface LinkOperation () <CBCentralManagerDelegate, CBPeripheralDelegate>

@end

@implementation LinkOperation

- (instancetype)init
{
    _peripheralArray = [NSMutableArray arrayWithCapacity:0];
    
    return self;
}

- (CBCentralManager *)centeralManager
{
    if (!_centeralManager) {
        _centeralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                queue:nil];
    }
    
    return _centeralManager;
}

//搜索蓝牙设备
- (void)searchlinkDevice
{
    // 实现代理
    // 扫描设备
//    _centeralManager = [[CBCentralManager alloc] initWithDelegate:self
//                                                            queue:nil];
    
    if(self.centeralManager.state == CBCentralManagerStatePoweredOff) {
        // 蓝牙关闭的
        
    } else if(self.centeralManager.state == CBCentralManagerStateUnsupported) {
        // 设备不支持蓝牙
    } else if(self.centeralManager.state == CBCentralManagerStatePoweredOn ||
              self.centeralManager.state == CBCentralManagerStateUnknown) {
        
        // 开启的话开始扫描蓝牙设备
        [self.centeralManager scanForPeripheralsWithServices:nil options:nil];
        
        double delayInSeconds = 20.0;
        
        // 扫描20s后未扫描到设备停止扫描
        dispatch_time_t popTime =
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime,
                       dispatch_get_main_queue(),
                       ^(void) {
            [self stopScan];
        });
    }
}

#pragma mark - 中心设备manager回调 -

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
        {
            // 扫描外围设备
            [self.centeralManager scanForPeripheralsWithServices:nil options:nil];
        }
            break;
            
        default:
            NSLog(@"设备蓝牙未开启");
            break;
    }
}

#pragma mark - 发现设备Delegate -

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    /**
     *  在ios中蓝牙广播信息中通常会包含以下4中类型的信息。ios的蓝牙通信协议中默认不接受其他类型的广播信息。因此需要注意的是，如果需要在扫描设备时，通过蓝牙设备的Mac地址来唯一辨别设备，那么需要与蓝牙设备的硬件工程师沟通好：将所需要的Mac地址放到一下几种类型的广播信息中。
     kCBAdvDataIsConnectable = 1;
     kCBAdvDataLocalName = SN00000003;
     kCBAdvDataManufacturerData = <43474d01>;
     kCBAdvDataTxPowerLevel = 0;
     */

    NSLog(@"advertisementData.kCBAdvDataManufacturerData = %@", advertisementData[@"kCBAdvDataManufacturerData"]);
    
    // 设备的UUID（peripheral.identifier）是由两个设备的mac通过算法得到的，所以不同的手机连接相同的设备，它的UUID都是不同的，无法标识设备
    // 苹果与蓝牙设备连接通信时，使用的并不是苹果蓝牙模块的Mac地址，使用的是苹果随机生成的十六进制码作为手机蓝牙的Mac与外围蓝牙设备进行交互。如果蓝牙设备与手机在一定时间内多次通信，那么使用的是首次连接时随机生成的十六进制码作为Mac地址，超过这个固定的时间段，手机会清空已随机生成的Mac地址，重新生成。
    // 也就是说外围设备是不能通过与苹果手机的交互时所获取的蓝牙Mac地址作为手机的唯一标识的。
    _connectPeripheral = peripheral;
//    [self.centeralManager connectPeripheral:peripheral options:nil];
    
   if ([advertisementData[@"kCBAdvDataLocalName"] hasPrefix:@"SN"]){
        NSLog(@"已搜索到设备");
        NSLog(@"peripheral.identifier = %@  peripheral.name = %@", peripheral.identifier, peripheral.name);
        
        [_delegate getAdvertisementData:advertisementData andPeripheral:peripheral];
        
        [_peripheralArray addObject:peripheral];
    }
}

#pragma mark - 连接设备 -

- (void)connectDiscoverPeripheral
{
    [self.centeralManager connectPeripheral:_connectPeripheral options:nil];
}

#pragma mark - 断开连接 -

- (void)cancelConnectPeripheral
{
    [self.centeralManager cancelPeripheralConnection:_connectPeripheral];
}

#pragma mark - 停止扫描 -

- (void)stopScan
{
    [self.centeralManager stopScan];
}

#pragma mark - 设备连接失败 -

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [_operationDelegate failToConnect];
}

#pragma mark - 设备连接中断 -

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"连接断开 %@", [error localizedDescription]);
    [_operationDelegate disconnected];
}

#pragma mark - 设备连接成功 -

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    // 设备停止扫描
    [self.centeralManager stopScan];
    
    peripheral.delegate = self;
    
    dispatch_after(2, dispatch_get_main_queue(), ^{
        
        // 查找服务
        [_connectPeripheral discoverServices:@[[CBUUID UUIDWithString:kCGMServiceTwoUUID]]];
    });
}

#pragma mark - 如果发现服务，则搜索特征 -

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        // 输出错误信息
        NSLog(@"discoverServices.error============ %@", [error localizedDescription]);
        
        return;
    }
    
    // 遍历设备提供的服务
    for (CBService *service in peripheral.services) {
        NSLog(@"service.UUID = ------------- = %@", service.UUID.UUIDString);
        
        // 找到需要的服务，并获取该服务响应的特性
        if([service.UUID isEqual:[CBUUID UUIDWithString:kCGMServiceTwoUUID]]) {
            [service.peripheral discoverCharacteristics:nil forService:service];
            NSLog(@"开始查找cgm的characteristic");
        }
    }
}

#pragma mark - 返回设备特征 -

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        // 输出错误信息
        NSLog(@"discoverCharacteristics.error=========== %@", [error localizedDescription]);
        return;
    }
    
    // 遍历服务中的所有特性
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCGMCharacteristicOneUUID]]) {
            // 设置读写的特性
            _readAndWriteCharacteristic = characteristic;
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCGMCharacteristicTwoUUID]]) {
            // 设置需要订阅的特性
            _notifyCharacteristic = characteristic;
            [_connectPeripheral setNotifyValue:YES forCharacteristic:_notifyCharacteristic];
        }
    }
}

// 写数据
- (void)writeCharacter:(NSData *)data
{
    NSLog(@" characteristic.uuid = %@ data ==== %@", _readAndWriteCharacteristic.UUID.UUIDString, data);
    if ([_readAndWriteCharacteristic.UUID isEqual:[CBUUID UUIDWithString:kCGMCharacteristicOneUUID]]) {
        [_connectPeripheral writeValue:data
                        forCharacteristic:_readAndWriteCharacteristic
                                     type:CBCharacteristicWriteWithResponse];
    } else {
        [_connectPeripheral writeValue:data
                        forCharacteristic:_readAndWriteCharacteristic
                                     type:CBCharacteristicWriteWithoutResponse];
    }
    
}

// 读取蓝牙信息 （但并不是在返回值中接受，要在- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error 这个回调方法中接收）
- (void)readCharacter
{
    [_connectPeripheral readValueForCharacteristic:_readAndWriteCharacteristic];
}

// 外围设备数据更新的回调方法， 可以在此回调方法中读取信息（无论是read的回调，还是notify（订阅）的回调都是此方法）
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        // 输出错误信息
        NSLog(@"didupadteValueForCharacteristic error ============ %@", [error localizedDescription]);
        
        return;
    }
    
    NSLog(@"value ============= %@", characteristic.value);
    
    // 解析数据
    NSData *data = characteristic.value;
    
    // 将NSData转Byte数组
    NSUInteger len = [data length];
    Byte *byteData = (Byte *)malloc(len);
    memcpy(byteData, [data bytes], len);
    
    NSMutableArray *commandArray = [NSMutableArray arrayWithCapacity:0];
    
    // Byte数组转字符串
    for (int i = 0; i < len; i++) {
        NSString *str = [NSString stringWithFormat:@"%02x", byteData[i]];
        [commandArray addObject:str];
        NSLog(@"byteData = %@", str);
    }
    
    // 输出数据
    [_operationDelegate dataWithCharacteristic:commandArray];
    
}

// 对特性已写入的回调(如果写入类型为CBCharacteristicWriteWithResponse 回调此方法，如果写入类型为CBCharacteristicWriteWithoutResponse不回调此方法)
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"write.error=======%@",error.userInfo);
    }
    
    /* When a write occurs, need to set off a re-read of the local CBCharacteristic to update its value */
    
    // 读数据
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCGMCharacteristicOneUUID]]) {
        [self readCharacter];
    }
}

// 订阅特征值通知状态改变成功的回调
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"error = %@", [error localizedDescription]);
    }
    
    // 对特性kCGMCharacteristicTwoUUID设置notify(订阅)，成功以后回调
    if ([characteristic.UUID.UUIDString isEqualToString:kCGMCharacteristicTwoUUID] && characteristic.isNotifying) {
        
        // 写数据 回调-didWriteValueForCharacteristic
        // 需要注意的是这里是对kCGMCharacteristicOneUUID这个特性进行写入，这里之所以这样操作是因为蓝牙设备的蓝牙协议是这样定义的，所以这里不要照抄照搬，要按照你的蓝牙设备的通讯协议来确定，对哪一个特性进行read，对哪个特性进行write，以及对哪个特性进行设置Notify
        NSLog(@"写数据到cgm设备的characteristic = %@", _readAndWriteCharacteristic.UUID.UUIDString);
        [_operationDelegate writeCharacteristic];
    }
}

// 将传入的NSData类型转换成NSString并返回
- (NSString *)hexadecimalString:(NSData *)data{
    NSString* result;
    const unsigned char* dataBuffer = (const unsigned char*)[data bytes];
    if(!dataBuffer){
        return nil;
    }
    NSUInteger dataLength = [data length];
    NSMutableString* hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for(int i = 0; i < dataLength; i++){
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    result = [NSString stringWithString:hexString];
    return result;
}

@end
