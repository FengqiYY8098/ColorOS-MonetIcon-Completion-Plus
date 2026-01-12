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

def fix_and_clean_icons():
    # 获取脚本所在目录
    script_path = os.path.abspath(__file__)
    current_dir = os.path.dirname(script_path)
    
    target_dir = os.path.join(current_dir, 'uxicons')

    if not os.path.exists(target_dir):
        print(f"❌ 错误：找不到 'uxicons' 文件夹。")
        return

    print(f"🚀 开始处理：格式修复(RGBA) + 元数据清理...")
    print(f"📂 目标目录: {target_dir}")

    count = 0
    error_count = 0

    # 遍历 uxicons 文件夹
    for root, dirs, files in os.walk(target_dir):
        for file in files:
            # 只处理 monochrome.png
            if file == "monochrome.png":
                file_path = os.path.join(root, file)
                
                try:
                    # 1. 打开原图
                    img = Image.open(file_path)
                    img.load() # 强制加载数据

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
                    clean_img.save(file_path, "PNG", optimize=True, compress_level=9)
                    
                    # 打印进度 (可选)
                    # print(f"✨ 已修复: {os.path.basename(root)}")
                    count += 1
                    
                except Exception as e:
                    print(f"❌ 处理失败 {file_path}: {e}")
                    error_count += 1

    print("-" * 30)
    print(f"🎉 全部完成！")
    print(f"✅ 成功修复并清理: {count} 个图标")
    if error_count > 0:
        print(f"⚠️ 失败: {error_count} 个")
    else:
        print(f"✨ 所有图标现在都应该是标准的 RGBA 格式了。")

if __name__ == "__main__":
    fix_and_clean_icons()