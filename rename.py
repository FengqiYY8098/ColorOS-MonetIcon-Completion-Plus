import os

def rename_files_to_monochrome():
    # 获取脚本所在目录
    script_path = os.path.abspath(__file__)
    current_dir = os.path.dirname(script_path)
    
    # 目标目录
    target_dir = os.path.join(current_dir, 'uxicons')

    if not os.path.exists(target_dir):
        print(f"❌ 错误：找不到 'uxicons' 文件夹。请确保它和脚本在同一目录下。")
        return

    print(f"🚀 开始重命名操作...")
    
    renamed_count = 0
    skipped_count = 0

    # 遍历 uxicons 下的所有子文件夹 (例如 com.android.chrome)
    for package_name in os.listdir(target_dir):
        package_path = os.path.join(target_dir, package_name)

        # 确保处理的是文件夹
        if os.path.isdir(package_path):
            # 获取文件夹内的文件列表
            files = os.listdir(package_path)
            
            # 过滤掉系统隐藏文件 (如 .DS_Store 或 Thumbs.db)
            valid_files = [f for f in files if not f.startswith('.')]

            if not valid_files:
                # 文件夹是空的
                continue
            
            # 取第一个文件 (假设每个文件夹里只有一个图标文件)
            old_filename = valid_files[0]
            
            # 分离文件名和后缀
            name, ext = os.path.splitext(old_filename)

            # 如果已经是 monochrome 了，就跳过
            if name == "monochrome":
                skipped_count += 1
                continue

            # 构建旧路径和新路径
            old_file_path = os.path.join(package_path, old_filename)
            new_filename = "monochrome" + ext
            new_file_path = os.path.join(package_path, new_filename)

            try:
                # 执行重命名
                os.rename(old_file_path, new_file_path)
                print(f"✏️ 重命名: {package_name}/{old_filename} -> {new_filename}")
                renamed_count += 1
            except Exception as e:
                print(f"❌ 错误 ({package_name}): {e}")

    print("-" * 30)
    print(f"🎉 完成！")
    print(f"✅ 成功重命名: {renamed_count} 个")
    print(f"⏭️ 跳过 (已是monochrome): {skipped_count} 个")

if __name__ == "__main__":
    rename_files_to_monochrome()