//点击识别按钮，调用相机
if([CameraRules isCapturePermissionGranted]){
        [self setDeviceAuthorized:YES];
    }
    else{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString* info=@"没有相机权限";
            [self showAlert:info];
            [self setDeviceAuthorized:NO];
        });
    }

 //CameraRules类，检测相机权限
 //检测相机权限
+(BOOL)isCapturePermissionGranted{
    if([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]){
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if(authStatus ==AVAuthorizationStatusRestricted || authStatus ==AVAuthorizationStatusDenied){
            return NO;
        }
        else if(authStatus==AVAuthorizationStatusNotDetermined){
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            __block BOOL isGranted=YES;
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                isGranted=granted;
                dispatch_semaphore_signal(sema);
            }];
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            return isGranted;
        }
        else{
            return YES;
        }
    }
    else{
        return YES;
    }
}

//初始化页面，创建摄像页面，创建张嘴数据和摇头数据
    //创建摄像页面，创建张嘴数据和摇头数据
    [self faceUI];
    [self faceCamera];
    [self faceNumber];

//开启识别，脸部框识别
    float cx = (left+right)/2;
    float cy = (top + bottom)/2;
    float w = right - left;
    float h = bottom - top;
    float ncx = cy ;
    float ncy = cx ;
    
    CGRect rectFace = CGRectMake(ncx-w/2 ,ncy-w/2 , w, h);
    
    if(!isFrontCamera){
        rectFace=rSwap(rectFace);
        rectFace=rRotate90(rectFace, faceImg.height, faceImg.width);
    }
    
    BOOL isNotLocation = [self identifyYourFaceLeft:left right:right top:top bottom:bottom];
    
    if (isNotLocation==YES) {
        return nil;
    }

//脸部部位识别，脸部识别判断是否检测到人脸
    for(id key in keys){
        id attr=[landmarkDic objectForKey:key];
        if(attr && [attr isKindOfClass:[NSDictionary class]]){
            
            if(!isFrontCamera){
                p=pSwap(p);
                p=pRotate90(p, faceImg.height, faceImg.width);
            }
            if (isCrossBorder == YES) {
                [self delateNumber];
                return nil;
            }
            p=pScale(p, widthScaleBy, heightScaleBy);
            
            [arrStrPoints addObject:NSStringFromCGPoint(p)];
            
        }
    }

//检测到人脸之后，判断位置动作提醒
    if (right - left < 230 || bottom - top < 250) {
        self.textLabel.text = @"太远了";
        [self delateNumber];
        isCrossBorder = YES;
        return YES;
    }else if (right - left > 320 || bottom - top > 320) {
        self.textLabel.text = @"太近了";
        [self delateNumber];
        isCrossBorder = YES;
        return YES;
    }else{
        if (isJudgeMouth != YES) {
            self.textLabel.text = @"请重复张嘴动作";
            [self tomAnimationWithName:@"openMouth" count:2];
            
            if (left < 100 || top < 100 || right > 460 || bottom > 400) {
                isCrossBorder = YES;
                isJudgeMouth = NO;
                self.textLabel.text = @"调整下位置先";
                [self delateNumber];
                return YES;
            }
        }else if (isJudgeMouth == YES && isShakeHead != YES) {
            self.textLabel.text = @"请重复摇头动作";
            [self tomAnimationWithName:@"shakeHead" count:4];
            number = 0;
        }else{
            takePhotoNumber += 1;
            if (takePhotoNumber == 2) {
                [self timeBegin];
            }
        }
        isCrossBorder = NO;
    }

//位置判断合适，判断是否张嘴
    if (rightX && leftX && upperY && lowerY && isJudgeMouth != YES) {
        
        number ++;
        if (number == 1 || number == 300 || number == 600 || number ==900) {
            mouthWidthF = rightX - leftX < 0 ? abs(rightX - leftX) : rightX - leftX;
            mouthHeightF = lowerY - upperY < 0 ? abs(lowerY - upperY) : lowerY - upperY;
            NSLog(@"%d,%d",mouthWidthF,mouthHeightF);
        }else if (number > 1200) {
            [self delateNumber];
            [self tomAnimationWithName:@"openMouth" count:2];
        }
        
        mouthWidth = rightX - leftX < 0 ? abs(rightX - leftX) : rightX - leftX;
        mouthHeight = lowerY - upperY < 0 ? abs(lowerY - upperY) : lowerY - upperY;
        NSLog(@"%d,%d",mouthWidth,mouthHeight);
        NSLog(@"张嘴前：width=%d，height=%d",mouthWidthF - mouthWidth,mouthHeight - mouthHeightF);
        if (mouthWidth && mouthWidthF) {
           
            if (mouthHeight - mouthHeightF >= 20 && mouthWidthF - mouthWidth >= 15) {
                isJudgeMouth = YES;
                imgView.animationImages = nil;
            }
        }
    }
//张嘴判断完毕，验证是否摇头
if ([key isEqualToString:@"mouth_middle"] && isJudgeMouth == YES) {
        
        if (bigNumber == 0 ) {
            firstNumber = p.x;
            bigNumber = p.x;
            smallNumber = p.x;
        }else if (p.x > bigNumber) {
            bigNumber = p.x;
        }else if (p.x < smallNumber) {
            smallNumber = p.x;
        }
       
        if (bigNumber - smallNumber > 60) {
            isShakeHead = YES;
            [self delateNumber];
        }
    }

//摇头判断完毕，3秒倒计时拍照
if(timeCount >= 1)
    {
        self.textLabel.text = [NSString  stringWithFormat:@"%ld s后拍照",(long)timeCount];
    }
    else
    {
        [theTimer invalidate];
        theTimer=nil;
        
        [self didClickTakePhoto];
    }

//拍照完毕，选择重拍或者上传图片
-(void)didClickPhotoAgain
{
    [self delateNumber];
    
    [self.previewLayer.session startRunning];
    self.textLabel.text = @"请调整位置";
    
    [backView removeFromSuperview];
    
    isJudgeMouth = NO;
    isShakeHead = NO;
    
}

//选择重拍重复5-9步骤，选择上传将图片数据回调
-(void)didClickUpPhoto
{
    //上传照片成功
    [self.faceDelegate sendFaceImage:imageView.image];
    [self.navigationController popViewControllerAnimated:YES];
}

//数据clean
-(void)delateNumber
{
    number = 0;
    takePhotoNumber = 0;
    
    mouthWidthF = 0;
    mouthHeightF = 0;
    mouthWidth = 0;
    mouthHeight = 0;
    
    smallNumber = 0;
    bigNumber = 0;
    firstNumber = 0;
    
    imgView.animationImages = nil;
    imgView.image = [UIImage imageNamed:@"shakeHead0"];
}
