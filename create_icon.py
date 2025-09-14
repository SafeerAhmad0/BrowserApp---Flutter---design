#!/usr/bin/env python3

"""
Script to create a clean browser app icon
"""

import os
from PIL import Image, ImageDraw

def create_browser_icon(size):
    """Create a clean browser icon"""
    # Create transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Calculate proportional sizes
    padding = size // 8
    browser_width = size - (padding * 2)
    browser_height = int(browser_width * 0.75)
    
    # Browser window outline
    browser_x = padding
    browser_y = (size - browser_height) // 2
    corner_radius = size // 24
    
    # Draw browser window background
    browser_rect = [browser_x, browser_y, browser_x + browser_width, browser_y + browser_height]
    draw.rounded_rectangle(browser_rect, radius=corner_radius, fill=(102, 126, 234, 255), outline=None)
    
    # Draw address bar
    address_bar_height = browser_height // 5
    address_rect = [browser_x, browser_y, browser_x + browser_width, browser_y + address_bar_height]
    draw.rounded_rectangle(address_rect, radius=corner_radius, fill=(82, 106, 214, 255), outline=None)
    
    # Draw window controls (three dots)
    dot_size = size // 40
    dot_y = browser_y + address_bar_height // 2
    dot_spacing = size // 20
    start_x = browser_x + dot_spacing
    
    for i in range(3):
        dot_x = start_x + (i * dot_spacing)
        dot_rect = [dot_x - dot_size, dot_y - dot_size, dot_x + dot_size, dot_y + dot_size]
        draw.ellipse(dot_rect, fill=(255, 255, 255, 200))
    
    # Draw address bar
    address_x = browser_x + browser_width // 3
    address_width = browser_width // 3
    address_height = size // 32
    address_rect = [address_x, dot_y - address_height//2, address_x + address_width, dot_y + address_height//2]
    draw.rounded_rectangle(address_rect, radius=address_height//2, fill=(255, 255, 255, 150))
    
    # Draw globe icon in content area
    content_y = browser_y + address_bar_height + padding//2
    globe_size = min(browser_width, browser_height - address_bar_height - padding) // 3
    globe_x = browser_x + (browser_width - globe_size) // 2
    globe_y = content_y + (browser_height - address_bar_height - padding - globe_size) // 2
    
    # Globe circle
    globe_rect = [globe_x, globe_y, globe_x + globe_size, globe_y + globe_size]
    stroke_width = max(2, size // 120)
    
    # Draw globe outline
    draw.ellipse(globe_rect, outline=(255, 255, 255, 255), width=stroke_width, fill=None)
    
    # Draw globe lines
    center_x = globe_x + globe_size // 2
    center_y = globe_y + globe_size // 2
    
    # Horizontal line
    draw.line([globe_x, center_y, globe_x + globe_size, center_y], fill=(255, 255, 255, 255), width=stroke_width//2)
    
    # Vertical curved lines
    for offset in [-globe_size//4, globe_size//4]:
        x = center_x + offset
        draw.line([x, globe_y, x, globe_y + globe_size], fill=(255, 255, 255, 255), width=stroke_width//2)
    
    return img

def main():
    # Create icons for different Android densities
    sizes = [
        (48, 'mdpi'),
        (72, 'hdpi'), 
        (96, 'xhdpi'),
        (144, 'xxhdpi'),
        (192, 'xxxhdpi')
    ]
    
    base_path = "android/app/src/main/res"
    
    for size, density in sizes:
        icon = create_browser_icon(size)
        
        # Create directory if it doesn't exist
        dir_path = f"{base_path}/mipmap-{density}"
        os.makedirs(dir_path, exist_ok=True)
        
        # Save icon
        icon_path = f"{dir_path}/ic_launcher.png"
        icon.save(icon_path, "PNG")
        print(f"Created {icon_path}")
    
    # Create web icons
    web_sizes = [192, 512]
    os.makedirs("web/icons", exist_ok=True)
    
    for size in web_sizes:
        icon = create_browser_icon(size)
        icon.save(f"web/icons/Icon-{size}.png", "PNG")
        icon.save(f"web/icons/Icon-maskable-{size}.png", "PNG")
        print(f"Created web/icons/Icon-{size}.png")
    
    # Create favicon
    favicon = create_browser_icon(32)
    favicon.save("web/favicon.png", "PNG")
    print("Created web/favicon.png")
    
    print("All icons created successfully!")

if __name__ == "__main__":
    main()