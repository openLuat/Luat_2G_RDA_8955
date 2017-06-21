#!/usr/bin/perl -w
# --------------------------------------------------------------------------- #
#       Copyright (C), AirM2M Comm. Co., Ltd. All rights reserved.            #
# --------------------------------------------------------------------------- #

# --------------------------------------------------------------------------- #
# This document contains proprietary information belonging to AirM2m.         #
# Passing on and copying of this document, use and communication of its       #
# contents is not permitted without prior written authorisation.              #
# --------------------------------------------------------------------------- #
#
# when       who     what, where, why
# YY.MM.DD   ---     ----------------
# --------   ---     --------------------------------------------------------
# 12.01.19   Lifei   Create
#---------------------------------------------------------------------------- #

# ------------------------------------------------------------------------
# 功能:
#     将lod文件和其他文件合并，生成新的lod文件
# 解决问题：
#     1. 带有AMC配置功能的版本，需要将AMC配置和平台lod文件合并
#     2. Lua版本，需要将lua脚本和平台lod文件合并
#     3. OpenAT版本，需要将cust lod和平台lod文件合并
# ------------------------------------------------------------------------

use strict;
use Config;
use File::Find;
use Getopt::Long;
use File::Basename;

my $g_dbg_level = "0";
   #0 No debug info
   #1 Main
   #2 Subroutines
   #3 Loops in Main
   #4 Loops in Subroutines
   #5 all

use constant {
    BIN_MODE => 1, #二进制文件，直接读取内容转换为hex后放入lod文件
    LOD_MODE => 2, #lod文件，内容为已经转换过的
};

my $combine_type; #amc, lua or openat
my $platform_lod_file;
my $combine_file;
my $output_lod_file;
my $flash_base;
my @sector_layout;

my %combine_type_hash = (
    "amc" =>    [BIN_MODE, "NV_BASE", "NV_SIZE"],
    "lua" =>    [BIN_MODE, "LUA_SCRIPT_BASE", "LUA_SCRIPT_SIZE"],
    "openat" => [LOD_MODE, "CUST_BASE", "CUST_SIZE"],
    "user" =>   [BIN_MODE, "USER_CONFIG_DATA_BASE", "USER_CONFIG_DATA_SIZE"]
);

#/*********************************************************
#  Function: dbg_out
#  Description: 输出调试信息
#  Input:
#    1. 输出信息的等级
#    2. 需要输出的信息
#  Output:
#  Return: 
#  Others:
#     根据当前全局变量g_dbg_level来决定是否需要输出信息
#*********************************************************/
sub dbg_out
{
    my $dbg_level = $_[0];
    my $dbg_info = $_[1];

    if ( $g_dbg_level >= $dbg_level )
    {
       printf "** $dbg_info\n";
    }
}

#/*********************************************************
#  Function: usage
#  Description: 输出该pl脚本的全部功能选项
#  Input:
#    1. 
#  Output:
#  Return: 
#  Others:
#     
#*********************************************************/
sub usage
{
    my $char = "";
    print "\n";
    print "Usage: perl $0 ";
    foreach my $type (keys %combine_type_hash)
    {
        print "$char\[$type\]";
        $char = "/" if($char eq "");
    }
    print " [arguments]\n";
    print "  More information, please enter:\n";
    print "  perl $0 ";
    $char = "";
    foreach my $type (keys %combine_type_hash)
    {
        print "$char\[$type\]";
        $char = "/" if($char eq "");
    }
    print " -h\n";
    print "\n";
    exit 1;
}

#/*********************************************************
#  Function: lod_combine_usage
#  Description: 输出amc合并功能选项
#  Input:
#    1. 
#  Output:
#  Return: 
#  Others:
#     
#*********************************************************/
sub lod_combine_usage
{
    my ($type) = @_;
    
    if($type eq "")
    {
        usage();
    }
    else
    {
        print "\n";
        print "Usage: perl $0 $type [arguments]\n";
        print "  -h\t\thelp information\n";
        print "  -l file\tinput platform lod file\n";
        print "  -i file\tinput $type file\n";
        print "  -o file\toutput combined lod file\n";
        print "\n";
    }
    exit 1;
}

sub init_sector_layout
{
    my ($tags_hash_ptr) = @_;
    my $sectormap_str;
    my @sectormap;
    my $sector_total_size = 0;
    
    if(!exists $tags_hash_ptr->{'sectormap'} || !exists $tags_hash_ptr->{'base'})
    {
        die "ERROR: platform lod file must contain tags: sectormap & base";
    }
    
    $flash_base = hex($tags_hash_ptr->{'base'});
    
    $sectormap_str = $tags_hash_ptr->{'sectormap'};
    $sectormap_str =~ s/\(|\)//g;
    $sectormap_str =~ s/\s//g;
    @sectormap = split(',', $sectormap_str);
    foreach my $item (@sectormap)
    {
        $item = lc($item);
        if($item =~ /(\d+)x(\d+)k/)
        {
            my $sector;
            $sector->{count} = $1;
            $sector->{size} = $2*1024;
            push(@sector_layout, $sector);
            $sector_total_size += $sector->{count} * $sector->{size};
        }
        else
        {
            die "ERROR: platform lod file with wrong sectormap: $tags_hash_ptr->{'sectormap'}";
        }
    }
    #检查一下flash size是否正确
    if(exists $tags_hash_ptr->{'FLASH_SIZE'})
    {
        my $flash_size = hex($tags_hash_ptr->{'FLASH_SIZE'});
        
        if($sector_total_size != $flash_size)
        {
            die "ERROR: platform lod file with wrong sectormap & flash_size: $sector_total_size<>$flash_size";
        }
    }
}

sub get_sector_size
{
    my ($addr) = @_;
    my $addr_start;
    my $sector_start_addr = 0;
    my $sector_size;
    
    if($addr < $flash_base)
    {
        die "ERROR: sector addr error: $addr < $flash_base";
    }
    
    $addr_start = $addr - $flash_base;
    
    foreach my $item (@sector_layout)
    {
        my $count = $item->{count} - 1;
        $sector_size = $item->{size};
        #dbg_out(5, "count:$item->{count}, size:$sector_size");
        foreach my $i (0..$count)
        {
            #dbg_out(5, "Sector size:$sector_start_addr, $addr_start");
            $sector_start_addr += $sector_size;
            if($sector_start_addr == $addr_start)
            {
                return $sector_size;
            }
        }
    }
    
    die "ERROR: cannot find sector size: $addr";
}

#/*********************************************************
#  Function: platform_lod_checksum
#  Description: 计算platform lod文件的checksum
#  Input:
#    1. 
#  Output:
#  Return: 
#  Others:
#     
#*********************************************************/
sub platform_lod_checksum
{
    my $line;
    my $checksum = 0;
    my $checksum_str;
    
    open( INPUT, "<$platform_lod_file" ) or die "Cannot open input platform lod file: $platform_lod_file\n";
    while( defined( $line = <INPUT> ) )
    {
        #chop( $line );#!!! window 读出来的数据带有\r\n，chop将\n去掉，留下了\r
        #$line =~ s/[\015\012]$//g;#将结尾的\r\n去掉
        $line =~ s/^[\s]+//g;#将开头的空白字符去掉
        $line =~ s/[\s]+$//g;#将结尾的空白字符去掉

        if($line eq "")
        {
            #空行继续
            next;
        }

        #tags
        if($line =~ /^([0-9A-Fa-f]+)$/)
        {
            $checksum += hex($1);
        }
    }
    close(INPUT);
    
    $checksum &= 0xffffffff;
    $checksum_str = sprintf("%08x", $checksum);
    dbg_out(1, "checksum=$checksum_str");
}

#/*********************************************************
#  Function: output_lod
#  Description: 输出到output lod文件中
#  Input:
#    1. output lod文件句柄
#    2. 输出信息
#    3. 要更新的checksum
#  Output:
#  Return: 
#  Others:
#     
#*********************************************************/
sub output_lod
{
    my ($output, $line, $checksum) = @_;
    
    if($line =~ /^([0-9A-Fa-f]+)$/)
    {
        $$checksum += hex($1);
    }
    
    print $output "$line\r\n";
}

#/*********************************************************
#  Function: lod_combine_process
#  Description: post_ld功能实现
#  Input:
#    1. 
#  Output:
#  Return: 
#  Others:
#     功能处理步骤：
#     step 1. 根据输入的rename file生成hash表
#     step 2. 根据 step 1 生成的hash表执行修改库名称的操作
#*********************************************************/
sub lod_combine_process
{
    my $line;
    my $line_num = 0;
    my @tags;
    my %tags_hash;
    my $addr = 0;
    my $combine_addr;
    my $combine_size;
    my $error;
    my $input_file_eof = 0;
    my $checksum = 0;
    my $OUTPUT;
    
    open( INPUT, "<$platform_lod_file" ) or die "Cannot open input platform lod file: $platform_lod_file\n";
    open( COMBINE, "<$combine_file" ) or die "Cannot open $combine_type combine file: $combine_file\n";
    open( $OUTPUT, ">$output_lod_file" ) or die "Cannot open output combined lod file: $output_lod_file\n";
    
    # step 1
    #读取platform lod文件头部信息
    while( defined( $line = <INPUT> ) )
    {
        $line_num++;
        #chop( $line );#!!! window 读出来的数据带有\r\n，chop将\n去掉，留下了\r
        #$line =~ s/[\015\012]$//g;#将结尾的\r\n去掉
        $line =~ s/^[\s]+//g;#将开头的空白字符去掉
        $line =~ s/[\s]+$//g;#将结尾的空白字符去掉

        if($line eq "")
        {
            #空行继续
            next;
        }

        #tags
        if($line =~ /^#\$([^=]+)=(.+)$/) #以#$开始
        {
            if(exists $tags_hash{$1})
            {
                die "ERROR: same tag in platform lod file:$platform_lod_file, tag($1)";
            }
            push(@tags, $1);
            $tags_hash{$1} = $2;
            
            next;
        }

        #first address
        elsif($line =~ /^@([0-9A-Fa-f]+)$/)
        {
            $addr = hex($1);
            last;
        }

        # other unknown content
        else
        {
            $error = "Bad platform lod file content:line$line_num\n";
            goto ERROR;
        }
    }
    init_sector_layout(\%tags_hash);
    dbg_out(5, "step 1 OK");
    
    # step 2
    #根据要合并的文件类型，找到起始地址和合并区域的大小
    if(!exists $combine_type_hash{$combine_type})
    {
        $error = "Unkown combine type: $combine_type";
        goto ERROR;
    }
    if(!exists $tags_hash{$combine_type_hash{$combine_type}[1]})
    {
        $error = "Cannot find combine address tag in platform lod file: $combine_type_hash{$combine_type}[1]";
        goto ERROR;
    }
    $combine_addr = hex($tags_hash{$combine_type_hash{$combine_type}[1]}) + $flash_base;
    if(!exists $tags_hash{$combine_type_hash{$combine_type}[2]})
    {
        $error = "Cannot find combine aera size tag in platform lod file: $combine_type_hash{$combine_type}[2]";
        goto ERROR;
    }
    $combine_size = hex($tags_hash{$combine_type_hash{$combine_type}[2]});
    dbg_out(5, "combine_addr=$combine_addr, combine_size=$combine_size");
    
    # step 3
    #检查 $combine_addr 的合法性
    #读取要合并的文件，看看是否超出可以使用的区域
    if(BIN_MODE == $combine_type_hash{$combine_type}[0])
    {
        my @file_args = stat($combine_file);
        dbg_out(5, "Combine file size: $file_args[7]");
    
        #只有bin模式的文件可以通过直接比较文件大小来决定是否可以放下
        if($file_args[7] > $combine_size)
        {
            $error = "Combine file is too large($file_args[7] bytes) than $combine_type area($combine_size bytes)";
            goto ERROR;
        }
    }
    else # LOD_MODE
    {
        my $first_addr = 0;
        my $last_addr = 0;
        seek(COMBINE, 0, 0);
        while( defined( $line = <COMBINE> ) )
        { 
            $line =~ s/^[\s]+//g;#将开头的空白字符去掉
            $line =~ s/[\s]+$//g;#将结尾的空白字符去掉
    
            if($line =~ /^@([0-9A-Fa-f]+)$/)
            {
                $first_addr = hex($1) if(0 == $first_addr);
                $last_addr = hex($1);
            }
            
            #tag
          if($line =~ /^#\$([^=]+)=(.+)$/) #以#$开始
	        {
	            if(!exists $tags_hash{$1})
	            {
                 	push(@tags, $1);
                 	$tags_hash{$1} = $2;
	            }
	            else
	            {
	                if($tags_hash{$1} ne $2 && $1 ne "sectormap")#忽略sectormap
	                {
	                  die "the parameter $1 $tags_hash{$1} and $2 is not same\n"
	                }	
	            }	            
	            next;
	        }            
        }
        seek(COMBINE, 0, 0);
        
        if($first_addr < $combine_addr)
        {
            $error = "cust lod start addrss($first_addr) outside of combine address($combine_addr)";
            goto ERROR;
        }
        if($last_addr > ($combine_addr+$combine_size))
        {
            $error = "cust lod end addrss($last_addr) outside of combine address($combine_addr+$combine_size)";
            goto ERROR;
        }
    }
    
    # step 4
    #合并输出，并计算checksum
    #输出头信息
    foreach my $item (@tags)
    {
        #print OUTPUT "#\$$item=$tags_hash{$item}\r\n";
        output_lod($OUTPUT, "#\$$item=$tags_hash{$item}", \$checksum);
    }
    #输出combine_addr之前的数据
    while($addr < $combine_addr)
    {
        $line = sprintf("@%08x", $addr);#需要补0
        #print OUTPUT "$line\r\n";
        output_lod($OUTPUT, $line, \$checksum);
        while( defined( $line = <INPUT> ) )
        {
            $line =~ s/^[\s]+//g;#将开头的空白字符去掉
            $line =~ s/[\s]+$//g;#将结尾的空白字符去掉
            
            if($line =~ /^@([0-9A-Fa-f]+)$/)
            {
                $addr = hex($1);
                last;
            }
            #print OUTPUT "$line\r\n";
            output_lod($OUTPUT, $line, \$checksum);
        }
    }
    dbg_out(5, "befor finish");
    
    #将原来lod文件的数据丢弃掉
    dbg_out(5, "$addr,$combine_addr,$combine_size");
    while($addr < ($combine_addr + $combine_size))
    {
        while( defined( $line = <INPUT> ) )
        {
            $line =~ s/^[\s]+//g;#将开头的空白字符去掉
            $line =~ s/[\s]+$//g;#将结尾的空白字符去掉
            
            if($line =~ /^@([0-9A-Fa-f]+)$/)
            {
                $addr = hex($1);
                last;
            }
        }
        
        if( !defined($line) )
        {
            $input_file_eof = 1;
            last;
        }
    }
    
    #输出combine file数据
    #有两个情况，一个是amc/lua这样的文件转换，一个是lod文件。
    #$combine_addr会被修改
    dbg_out(5, "Combine start ==========>>>>>>>>>>>>>>>>>>");
    if(BIN_MODE == $combine_type_hash{$combine_type}[0])
    {
        my $buf;
        my @data;
        my $num = 0;
        my $write_size = 0;
        my $sector_size = get_sector_size($combine_addr);
        $line = sprintf("@%08x", $combine_addr);#需要补0
        dbg_out(5, "$line");
        #print OUTPUT "$line\r\n";
        output_lod($OUTPUT, $line, \$checksum);
        binmode( COMBINE );#二进制模式
        while( defined($num = read(COMBINE, $buf, 4)) )
        {
            if($num == 0)
            {
                last;
            }
            $line = unpack("H*", $buf);
            $num = 4 - $num;
            $line .= "ff"x$num;
            @data = $line =~ /\w{2}/g;#每2位分割
            @data[0,1,2,3] = @data[3,2,1,0];#交换
            $line = "@data";
    		$line =~ s/\s//g;#替换空格
            #print OUTPUT "$line\r\n";
            output_lod($OUTPUT, $line, \$checksum);
            $write_size += 4;
    
            #写入1个sector后，需要写入新sector的地址
            if($write_size >= $sector_size)
            {
                $write_size = 0;
                $combine_addr += $sector_size;
                $sector_size = get_sector_size($combine_addr);
                $line = sprintf("@%08x", $combine_addr);#需要补0
                dbg_out(5, "$line");
                #print OUTPUT "$line\r\n";
                output_lod($OUTPUT, $line, \$checksum);
            }
        }
        #补齐该sector
=cut
        while($write_size < $sector_size)
        {
            $line = "ffffffff";
            #print OUTPUT "$line\r\n";
            output_lod($OUTPUT, $line, \$checksum);
            $write_size += 4;
        }
=cut
    }
    elsif(LOD_MODE == $combine_type_hash{$combine_type}[0])
    {
        my %cust_lod_tags_hash;
        my $cust_lod_addr = 0;
        my $cust_lod_line_num = 0;
        
        while( defined( $line = <COMBINE> ) )
        {
            $cust_lod_line_num++;
            $line =~ s/^[\s]+//g;#将开头的空白字符去掉
            $line =~ s/[\s]+$//g;#将结尾的空白字符去掉
    
            if($line eq "")
            {
                #空行继续
                next;
            }
    
            #tags
            if($line =~ /^#\$([^=]+)=(.+)$/) #以#$开始
            {
                if(exists $cust_lod_tags_hash{$1})
                {
                    die "ERROR: same tag in custom lod file:$combine_file, tag($1)";
                }
                $cust_lod_tags_hash{$1} = $2;
                
                next;
            }
            #first address
            elsif($line =~ /^@([0-9A-Fa-f]+)$/)
            {
                $cust_lod_addr = hex($1);
                last;
            }
    
            # other unknown content
            else
            {
                $error = "Bad custom lod file content:line$cust_lod_line_num\n";
                goto ERROR;
            }
        }
        #cust lod中的第一个地址一定要比允许merge的地址要小
        if($cust_lod_addr < $combine_addr)
        {
            $error = "Bad custom lod file: cust first address $cust_lod_addr < $combine_addr\n";
            goto ERROR;
        }
        
        #这里还可以两个lod文件的flash类型是否匹配等信息
        
        #copy cust lod文件内容到output lod文件中
        $combine_addr = $cust_lod_addr;
        $line = sprintf("@%08x", $combine_addr);#需要补0
        dbg_out(5, "$line");
        #print OUTPUT "$line\r\n";
        output_lod($OUTPUT, $line, \$checksum);
        while( defined( $line = <COMBINE> ) )
        {
            $line =~ s/^[\s]+//g;#将开头的空白字符去掉
            $line =~ s/[\s]+$//g;#将结尾的空白字符去掉
            
            if($line =~ /^#checksum/)
            {
                #文件结束了
                dbg_out(5, "cust lod last");
                last;
            }
            elsif($line =~ /^@([0-9A-Fa-f]+)$/)
            {
                $combine_addr = hex($1);
                dbg_out(5, "$line");
            }
            elsif($line eq "")
            {
                next;
            }
            #print OUTPUT "$line\r\n";
            output_lod($OUTPUT, $line, \$checksum);
        }
    }
    else
    {
        $error = "Unknown combine type:$combine_type";
        goto ERROR;
    }
    dbg_out(5, "Combine finish ==========>>>>>>>>>>>>>>>>>>");
    
    #输出combine_addr之后的数据
    if($input_file_eof == 0)
    {
        if($addr < $combine_addr)#此处的combine_addr已经被修改为最后一个地址了
        {
            $error = "ERROR: combine data too large: $addr < $combine_addr!";
            goto ERROR;
        }
        $line = sprintf("@%08x", $addr);#需要补0
        #print OUTPUT "$line\r\n";
        output_lod($OUTPUT, $line, \$checksum);
        while( defined( $line = <INPUT> ) )
        {
            $line =~ s/^[\s]+//g;#将开头的空白字符去掉
            $line =~ s/[\s]+$//g;#将结尾的空白字符去掉
            
            if($line =~ /^#checksum/)
            {
                #文件结束了
                dbg_out(5, "last");
                last;
            }
            elsif($line eq "")
            {
                next;
            }
            #print OUTPUT "$line\r\n";
            output_lod($OUTPUT, $line, \$checksum);
        }
    }
    
    #输出checksum
    $checksum &= 0xffffffff;
    $line = sprintf("#checksum=%08x", $checksum);
    output_lod($OUTPUT, $line, \$checksum);
    
    close(INPUT);
    close(COMBINE);
    close($OUTPUT);
    return;
    
ERROR:
    close(INPUT);
    close(COMBINE);
    close($OUTPUT);
    unlink($output_lod_file);
    
    die "$error";
}

#/*********************************************************
#  Function: lod_combine
#  Description: prev_ld功能参数解析
#  Input:
#    1. 参数列表数组
#  Output:
#  Return: 
#  Others:
#     
#*********************************************************/
sub lod_combine
{
    my $i = 0;
    
    #获取参数
    while( $_[$i] )
    {
        my $key = $_[$i];

        dbg_out("1", "key: $key");
        
        # -h help
        if ($key eq "-h")
        {
            lod_combine_usage($combine_type);
        }

        # -l input lod file
        elsif ($key eq "-l")
        {
            $i++;
            $platform_lod_file = $_[$i];
            dbg_out("1", "platform_lod_file=$platform_lod_file");
            $i++;
        }

        # -i input combine file
        elsif ($key eq "-i" )
        {
            $i++;
            $combine_file = $_[$i];
            dbg_out("1", "combine_file=$combine_file");
            $i++;
        }

        # -o output combined lod file
        elsif ($key eq "-o" )
        {
            $i++;
            $output_lod_file = $_[$i];
            dbg_out("1", "output_lod_file=$output_lod_file");
            $i++;
        }
        
        # not valid parameter
        else
        {
            dbg_out("1", "not valid parameter");
            lod_combine_usage($combine_type);
        }
    }
    
    if($platform_lod_file eq "" || $combine_file eq "" || $output_lod_file eq "")
    {
        print "Parameter error!\n\n";
        lod_combine_usage($combine_type);
    }
    
    dbg_out("1", "parameter ok");

    lod_combine_process();
    #platform_lod_checksum();
}

#**********************************************************
# lua
#**********************************************************

#**********************************************************
# openat
#**********************************************************

# ------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------
if( not defined $ARGV[0])
{
    dbg_out("1", "no parameters");
    usage();
}
else
{
    my $key = $ARGV[0];

    dbg_out("1", "key: $key");
    
    #获取合并类型
    if(defined($combine_type_hash{$key}))
    {
        shift @ARGV;
        $combine_type = $key;
    }
    
    # not valid parameter
    else
    {
        dbg_out("1", "not valid parameter");
        usage();
    }
    
    lod_combine(@ARGV);
}

exit 0;