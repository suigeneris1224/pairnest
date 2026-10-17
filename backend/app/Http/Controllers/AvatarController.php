<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

/**
 * Profile photos, kept private: only the person and their partner can fetch
 * them. Uploads are squared to 512px and re-encoded, which drops EXIF data
 * such as GPS location.
 */
class AvatarController extends Controller
{
    private const SIZE = 512;

    private const DIR = 'avatars';

    public function store(Request $request): JsonResponse
    {
        $request->validate(['photo' => ['required', 'image', 'mimes:jpeg,png,webp', 'max:8192']]);
        $file = $request->file('photo');

        $jpeg = $this->normalise($file->getRealPath(), $file->getMimeType());
        $path = self::DIR.'/'.Str::random(40).'.jpg';
        Storage::disk('local')->put($path, $jpeg);

        $user = $request->user();
        if ($user->avatar_path) {
            Storage::disk('local')->delete($user->avatar_path);
        }
        $user->forceFill(['avatar_path' => $path, 'avatar_updated_at' => now()])->save();

        return response()->json(['user' => $user->load('couple.members')]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user->avatar_path) {
            Storage::disk('local')->delete($user->avatar_path);
        }
        $user->forceFill(['avatar_path' => null, 'avatar_updated_at' => null])->save();

        return response()->json(['user' => $user->load('couple.members')]);
    }

    /** Your own photo, or your partner's; anyone else gets a 404. */
    public function show(Request $request, int $id): Response
    {
        $me = $request->user();
        $member = $id === $me->id ? $me : User::where('id', $id)->whereNotNull('couple_id')->where('couple_id', $me->couple_id)->first();
        if (! $member || ! $member->avatar_path || ! Storage::disk('local')->exists($member->avatar_path)) {
            abort(404);
        }

        return response(Storage::disk('local')->get($member->avatar_path), 200, [
            'Content-Type' => 'image/jpeg',
            'Cache-Control' => 'private, max-age=86400',
        ]);
    }

    /** Upright, centre-cropped, 512px JPEG with no metadata. */
    private function normalise(string $path, ?string $mime): string
    {
        $image = match ($mime) {
            'image/png' => @imagecreatefrompng($path),
            'image/webp' => @imagecreatefromwebp($path),
            default => @imagecreatefromjpeg($path),
        };
        if (! $image) {
            throw ValidationException::withMessages(['photo' => "That photo couldn't be read. Try another one."]);
        }

        // Phones store rotation in EXIF; apply it before the metadata is dropped.
        if ($mime === 'image/jpeg' && function_exists('exif_read_data')) {
            $orientation = (int) (@exif_read_data($path)['Orientation'] ?? 1);
            $image = match ($orientation) {
                3 => imagerotate($image, 180, 0),
                6 => imagerotate($image, -90, 0),
                8 => imagerotate($image, 90, 0),
                default => $image,
            };
        }

        $w = imagesx($image);
        $h = imagesy($image);
        $side = min($w, $h);
        $square = imagecreatetruecolor(self::SIZE, self::SIZE);
        // White behind transparent PNGs instead of black.
        imagefill($square, 0, 0, imagecolorallocate($square, 255, 255, 255));
        imagecopyresampled($square, $image, 0, 0, intdiv($w - $side, 2), intdiv($h - $side, 2), self::SIZE, self::SIZE, $side, $side);

        ob_start();
        imagejpeg($square, null, 85);

        return (string) ob_get_clean();
    }
}
