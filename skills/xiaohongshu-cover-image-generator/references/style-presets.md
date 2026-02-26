# Style Presets Reference

8 predefined styles optimized for DashScope wan2.6-t2i, designed for XHS cover backgrounds with text overlay.

## Styles

### `cyberpunk`

- **Prompt prefix**: Cyberpunk neon cityscape, dark background, vibrant neon lights, futuristic tech aesthetic, glowing circuits, digital rain
- **Best for**: Tech articles, AI/blockchain topics, gaming content, night city vibes
- **Color palette**: Deep purple, neon pink, electric blue, dark backgrounds

### `minimalist`

- **Prompt prefix**: Clean minimalist flat design, solid color blocks, geometric shapes, ample white space, modern sans-serif aesthetic
- **Best for**: Lifestyle tips, productivity, wellness, clean branding
- **Color palette**: Muted pastels, white/cream, single accent color

### `infographic`

- **Prompt prefix**: Professional infographic background, subtle icons, flowing data lines, clean grid layout, muted corporate colors
- **Best for**: Data-driven content, business insights, research summaries, how-to guides
- **Color palette**: Corporate blues, greens, neutral grays

### `realistic_scene`

- **Prompt prefix**: Realistic photography scene, professional lighting, shallow depth of field, cinematic composition, high-end commercial look
- **Best for**: Food, travel, product showcases, nature scenes
- **Color palette**: Natural, warm tones, cinematic grading

### `watercolor`

- **Prompt prefix**: Watercolor painting style, soft pastel colors, artistic texture, flowing pigment edges, dreamy atmosphere
- **Best for**: Art/culture content, poetry, emotional storytelling, seasonal themes
- **Color palette**: Soft pastels, flowing color transitions

### `gradient_abstract`

- **Prompt prefix**: Abstract gradient background, modern color transitions, geometric patterns, soft bokeh elements, contemporary design
- **Best for**: General purpose, announcements, quotes, versatile backgrounds
- **Color palette**: Modern gradients (purple-blue, coral-pink, teal-green)

### `tech_futuristic`

- **Prompt prefix**: Futuristic technology, circuit board patterns, holographic elements, dark tech background, blue and purple glow
- **Best for**: AI/ML, semiconductors, robotics, science topics
- **Color palette**: Dark blue, holographic, electric purple

### `nature_zen`

- **Prompt prefix**: Serene zen landscape, natural elements, soft golden light, peaceful atmosphere, bamboo and water
- **Best for**: Mindfulness, wellness, meditation, traditional culture, tea ceremony
- **Color palette**: Earth tones, soft greens, golden light

## Common Suffix (always appended)

```
, conceptual background image suitable for text overlay, high quality, 4K detail, no text, no watermark
```

## Negative Prompt (always applied)

```
人物, 人像, 自拍, 肖像, 面部, 头像, 手, 身体, people, person, portrait, face, selfie, human, body, hands, fingers, text, watermark, logo, signature, words, letters, typography
```

## Using `auto` Style

When `--style auto` (default), no style prefix is added. The user's prompt is used directly with only the concept suffix appended. Use this when the prompt already contains detailed style instructions.

## Tips

- Combine style with specific scene descriptions for best results: `--style cyberpunk "数据可视化仪表盘，深蓝色背景"`
- Chinese prompts work well; the model handles bilingual input
- Use `--seed N` to reproduce a specific image you liked
- Square aspect (`--aspect square`) works better for `minimalist` and `gradient_abstract` styles
