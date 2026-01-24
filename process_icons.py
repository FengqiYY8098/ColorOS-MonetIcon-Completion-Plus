import os
import sys

# 尝试导入 Pillow 库
try:
    from PIL import Image
except ImportError:
    print("❌ 错误：未安装 Pillow 库。")
    print("请先在终端运行：pip install pillow")
    input("按回车键退出...")
    sys.exit()

def process_icons():
    # 获取脚本所在目录
    script_path = os.path.abspath(__file__)
    current_dir = os.path.dirname(script_path)
    
    # 目标目录
    target_dir = os.path.join(current_dir, 'uxicons')

    if not os.path.exists(target_dir):
        print(f"❌ 错误：找不到 'uxicons' 文件夹。请确保它和脚本在同一目录下。")
        return

    print(f"🚀 开始处理：重命名及格式修复(RGBA)...")
    print(f"📂 目标目录: {target_dir}")
    
    renamed_count = 0
    cleaned_count = 0
    skipped_rename_count = 0
    error_count = 0

    # 获取所有子目录
    try:
        package_names = sorted(os.listdir(target_dir))
    except Exception as e:
        print(f"❌ 无法读取目录: {e}")
        return

    for package_name in package_names:
        package_path = os.path.join(target_dir, package_name)

        # 确保处理的是文件夹
        if not os.path.isdir(package_path):
            continue

        # 获取文件夹内的文件列表
        try:
            files = os.listdir(package_path)
        except Exception:
            continue
        
        # 过滤掉系统隐藏文件
        valid_files = [f for f in files if not f.startswith('.')]

        if not valid_files:
            continue
        
        # --- 步骤 1: 确定目标文件并重命名 ---
        
        # 策略：如果已经有 monochrome.* 文件，则优先使用它
        # 否则，取第一个文件作为目标
        target_file_name = None
        current_is_monochrome = False

        # 检查是否已有 monochrome.*
        for f in valid_files:
            name, ext = os.path.splitext(f)
            if name == "monochrome":
                target_file_name = f
                current_is_monochrome = True
                break
        
        # 如果没有，取第一个文件
        if not target_file_name:
            target_file_name = valid_files[0]
            current_is_monochrome = False

        name, ext = os.path.splitext(target_file_name)
        current_file_path = os.path.join(package_path, target_file_name)
        final_file_path = current_file_path

        if not current_is_monochrome:
            new_filename = "monochrome" + ext
            new_file_path = os.path.join(package_path, new_filename)
            try:
                os.rename(current_file_path, new_file_path)
                print(f"✏️ 重命名: {package_name}/{target_file_name} -> {new_filename}")
                renamed_count += 1
                final_file_path = new_file_path # 更新路径指向新文件
                target_file_name = new_filename # 更新文件名
            except Exception as e:
                print(f"❌ 重命名错误 ({package_name}): {e}")
                error_count += 1
                continue # 失败则跳过后续步骤
        else:
            skipped_rename_count += 1

        # --- 步骤 2: 清理/修复图片 (仅限 PNG) ---
        # 即使刚重命名过，也需要检查是否为 png 并进行清洗
        
        # 注意：这里我们使用 lower() 来判断后缀，兼容 .PNG
        if target_file_name.lower().endswith(".png"):
            try:
                # 1. 打开原图
                img = Image.open(final_file_path)
                img.load() # 强制加载

                # 2. 创建一张全新的 RGBA 画布
                # "RGBA" 模式保证了 output 是标准的 32位 带有透明通道的格式
                # 这一步解决了系统不识别索引颜色(Indexed Color)的问题
                clean_img = Image.new("RGBA", img.size)
                
                # 3. 将原图转为 RGBA 并贴上去
                # .convert("RGBA") 会自动处理灰度、索引等奇怪的格式
                clean_img.paste(img.convert("RGBA"), (0, 0))

                # 4. 覆盖保存
                # optimize=True: 压缩体积
                # compress_level=9: 最大压缩率
                clean_img.save(final_file_path, "PNG", optimize=True, compress_level=9)
                cleaned_count += 1
                
            except Exception as e:
                print(f"❌ 图片修复失败 {final_file_path}: {e}")
                error_count += 1

    print("-" * 30)
    print(f"🎉 全部完成！")
    print(f"✅ 执行重命名: {renamed_count} 个")
    print(f"⏭️ 无需重命名: {skipped_rename_count} 个")
    print(f"✨ 格式修复(PNG): {cleaned_count} 个")
    
    if error_count > 0:
        print(f"⚠️ 发生错误: {error_count} 个")
    else:
        print(f"✨ 所有图标处理完毕。")

if __name__ == "__main__":
    process_icons()
