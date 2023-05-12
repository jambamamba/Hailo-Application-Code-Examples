#!/bin/bash -xe
set -xe

#git clone https://github.com/hailo-ai/Hailo-Application-Code-Examples.git


function parseArgs(){
   for change in "$@"; do
      local name="${change%%=*}"
      local value="${change#*=}"
      eval $name="$value"
   done
}

function configure(){
    local rootdir="/media/isgdev/1885b256-daf3-4ea6-b95b-d4d23af9a578"
    #rm -f /opt/usr_data/sdk/sysroots/x86_64-oesdk-linux/environment-setup.d/icecc-env.sh
    source "${SDK_DIR}/environment-setup-cortexa72-oe-linux"

    mkdir -p cmake
    pushd cmake
    cp -f "${rootdir}/repos/pi4/build/tmp-glibc/work/cortexa72-oe-linux/libhailort/4.13.0-r0/build/hailort/libhailort/src/CMakeFiles/Export/lib/cmake/HailoRT/HailoRTTargets.cmake" .
    cp -f "${rootdir}/repos/pi4/build/tmp-glibc/work/cortexa72-oe-linux/libhailort/4.13.0-r0/build/hailort/libhailort/src/HailoRTConfig.cmake" .
    echo "
set_target_properties(HailoRT::libhailort PROPERTIES
    IMPORTED_LOCATION \"${rootdir}/lib/libhailort.so\"
    INTERFACE_INCLUDE_DIRECTORIES \"${rootdir}/include\"
)
" >> HailoRTConfig.cmake
    popd
    
    sudo mkdir -p /opt/usr_data/sdk/sysroots/cortexa72-oe-linux/usr/lib/opencv4/3rdparty/
    pushd /opt/usr_data/sdk/sysroots/cortexa72-oe-linux/usr/lib/opencv4/3rdparty/
    sudo cp -f ${rootdir}/repos/pi4/build/tmp-glibc/sysroots-components/cortexa72/opencv/usr/lib/opencv4/3rdparty/lib*.a .
    popd

    sudo mkdir -p "${rootdir}/include"
    pushd "${rootdir}/include"
    sudo rsync -uav ${rootdir}/repos/pi4/build/tmp-glibc/sysroots-components/cortexa72/libhailort/usr/include/hailort/hailo .
    popd

    sudo mkdir -p "${rootdir}/lib"
    pushd "${rootdir}/lib"
    sudo cp -f ${rootdir}/repos/pi4/build/tmp-glibc/sysroots-components/cortexa72/libhailort/usr/lib/libhailort.so .
    popd
}

function build() {
    parseArgs $@
    local cmake_module_path="$(pwd)/cmake"
    pushd "${app}"
    mkdir -p build
    if [ "${clean}" == "true" ]; then
        rm -fr build/*
    fi

    pushd build
    export HailoRT_DIR="${cmake_module_path}"
    HAILORT_VER=4.10.0 ARCH="aarch64" cmake \
        -DCMAKE_MODULE_PATH=${cmake_module_path} \
        -DCMAKE_PREFIX_PATH=${cmake_module_path} \
        ..
    make -j$(nproc)
    popd
    popd
}

function getData(){
    parseArgs $@
    local rsync="rsync -uav --progress"

    mkdir -p data
    pushd data
    # if [ ! -f full_mov_slow.mp4 ]; then
    #     wget https://hailo-tappas.s3.eu-west-2.amazonaws.com/v3.22/general/media/full_mov_slow.mp4
    # fi
    # if [ ! -f yolov5m_wo_spp.hef ]; then
    #     wget https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v2.6.0/yolov5m_wo_spp.hef
    # fi
    # if [ ! -f yolov7.hef ]; then
    #     wget https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v2.6.0/yolov7.hef
    # fi
    # # yolov5_yolov7_detection_cpp/get_hefs_and_video.sh
    # rm -f out*png
    # ../../pi4/docker/configs/custom/run/ff.sh  fn=videoToImages INPUT_FILE_PATH=full_mov_slow.mp4 OUTPUT_FRAME_RATE=3
    # ssh root@${ip} mkdir -p /data
    # ssh root@${ip} rm -fr /data/*
    # $rsync out.*.png root@${ip}:/data/
    # # $rsync full_mov_slow.mp4 root@${ip}:/data/
    # $rsync yolov5m_wo_spp.hef root@${ip}:/data/
    # $rsync yolov7.hef root@${ip}:/data/

    if [ ! -f yolov5s_personface.hef ]; then 
        wget https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v2.4.0/yolov5s_personface.hef
    fi
    if [ ! -f repvgg_a0_person_reid_2048.hef ]; then 
        wget https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v2.4.0/repvgg_a0_person_reid_2048.hef
    fi
    if [ ! -f reid.tar.gz ]; then 
        wget https://hailo-tappas.s3.eu-west-2.amazonaws.com/v3.21/general/media/re_id/reid.tar.gz
    fi
    mkdir -p video_images
    pushd video_images
    rm -fr *
    ln -sf ../reid.tar.gz .
    tar -xzvf reid.tar.gz
    ../../../pi4/docker/configs/custom/run/ff.sh  fn=videoToImages INPUT_FILE_PATH=reid0.mp4 OUTPUT_FRAME_RATE=3
    #ffmpeg -i reid0.mp4 -vf "fps=30" video_images/image%d.png
    popd

    ssh root@${ip} mkdir -p /data/video_images
    ssh root@${ip} rm -fr /data/video_images/*
    $rsync video_images/*.png root@${ip}:/data/video_images/
    $rsync yolov5s_personface.hef root@${ip}:/data/
    $rsync repvgg_a0_person_reid_2048.hef root@${ip}:/data/
    popd
    $rsync *json root@${ip}:/data/
}

function deploy(){
    parseArgs $@
    local rsync="rsync -uav --progress"
    $rsync yolov5_yolov7_detection_cpp/build/vstream_yolov5_yolov7_example_cpp root@$ip:/usr/local/bin/
    # /usr/local/bin/vstream_yolov5_yolov7_example_cpp -hef=/data/yolov7.hef -arch=aarch64 -video=/data/full_mov_slow.mp4
    $rsync segmentation_example_cpp/build/segmentation_example_cpp root@$ip:/usr/local/bin/
    # /usr/local/bin/segmentation_example_cpp -hef=/data/yolov7.hef -path=/data/full_mov_slow.mp4
    $rsync RE-ID_example_code/build/vstream_re_id_example root@$ip:/usr/local/bin/
    # cd /data && /usr/local/bin/vstream_re_id_example -hef=yolov5s_personface.hef -reid=repvgg_a0_person_reid_2048.hef -num=1
    # Results: about 30fps
    # -I-----------------------------------------------
    # -I- Total Time:               0.0330493 sec
    # -I- Average FPS:              30.2578
    # -I- Total Latency:            33.0493 ms
    # -I-----------------------------------------------

    # -I- Total inference run time: 63.0704 sec
    # root@raspberrypi4-64:/data# 
}

function main(){
    local ip="192.168.7.8"
    configure
    # build app=yolov5_yolov7_detection_cpp clean=false
    # build app=segmentation_example_cpp clean=false
    build app="RE-ID_example_code" clean=false

    deploy ip="${ip}"
    getData ip="${ip}"
}

time main


# #todo: setting up ssh server on pi:
# mkdir -p /home/root/.ssh/               
# touch /home/root/.ssh/authorized_keys
# vi ~/.ssh/authorized_keys
# copy pasted contents from host machine
# # To disable tunneled clear text passwords, change to no here!
# echo "
# PermitRootLogin yes
# UsePAM no
# PasswordAuthentication yes
# PermitEmptyPasswords yes
# " >> /etc/ssh/sshd_config
# ifconfig eth0 192.168.7.8
# #on host machine
# sudo ifconfig enxa0cec8caf91d 192.168.7.7
# sudo ip route add 192.168.7.0/24 dev enxa0cec8caf91d
# #sudo ip route show
# ssh root@192.168.7.8

