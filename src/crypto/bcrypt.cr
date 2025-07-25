require "random/secure"
require "./subtle"

# Pure Crystal implementation of the Bcrypt algorithm by Niels Provos and David
# Mazières, as [presented at USENIX in
# 1999](https://www.usenix.org/legacy/events/usenix99/provos/provos_html/index.html).
#
# The algorithm has a maximum password length limit of 71 characters (see
# [this comment](https://security.stackexchange.com/questions/39849/does-bcrypt-have-a-maximum-password-length#answer-39851)
# on stackoverflow).
#
# Refer to `Crypto::Bcrypt::Password` for a higher level interface.
#
# About the Cost
#
# Bcrypt, like the PBKDF2 or scrypt ciphers, are designed to be slow, so
# generating rainbow tables or cracking passwords is nearly impossible. Yet,
# computers are always getting faster and faster, so the actual cost must be
# incremented every once in a while.
# Always use the maximum cost that is tolerable, performance wise, for your
# application. Be sure to test and select this based on your server, not your
# home computer.
#
# This implementation of Bcrypt is currently 50% slower than pure C solutions,
# so keep this in mind when selecting your cost. It may be wise to test with
# Ruby's [bcrypt gem](https://github.com/codahale/bcrypt-ruby)
# which is a binding to OpenBSD's implementation.
#
# Last but not least: beware of denial of services! Always protect your
# application using an external strategy (eg: rate limiting), otherwise
# endpoints that verifies bcrypt hashes will be an easy target.
#
# NOTE: To use `Bcrypt`, you must explicitly import it with `require "crypto/bcrypt"`
class Crypto::Bcrypt
  class Error < Exception
  end

  DEFAULT_COST   = 11
  COST_RANGE     = 4..31
  PASSWORD_RANGE = 1..72
  SALT_SIZE      = 16

  private BLOWFISH_ROUNDS = 16
  private DIGEST_SIZE     = 31

  # bcrypt IV: "OrpheanBeholderScryDoubt"
  {% if compare_versions(Crystal::VERSION, "1.16.0") >= 0 %}
    private CIPHER_TEXT = Slice(UInt32).literal(
      0x4f727068, 0x65616e42, 0x65686f6c,
      0x64657253, 0x63727944, 0x6f756274,
    )
  {% else %}
    private CIPHER_TEXT = UInt32.static_array(
      0x4f727068, 0x65616e42, 0x65686f6c,
      0x64657253, 0x63727944, 0x6f756274,
    )
  {% end %}

  # Hashes the *password* using bcrypt algorithm using salt obtained via `Random::Secure.random_bytes(SALT_SIZE)`.
  #
  # ```
  # require "crypto/bcrypt"
  #
  # Crypto::Bcrypt.hash_secret "secret"
  # ```
  def self.hash_secret(password, cost = DEFAULT_COST) : String
    # We make a clone here to we don't keep a mutable reference to the original string
    passwordb = password.to_unsafe.to_slice(password.bytesize + 1).clone # include leading 0
    saltb = Random::Secure.random_bytes(SALT_SIZE)
    new(passwordb, saltb, cost).to_s
  end

  # Creates a new `Crypto::Bcrypt` object from the given *password* with *salt* and *cost*.
  #
  # *salt* must be a base64 encoded string of 16 bytes (128 bits).
  #
  # ```
  # require "crypto/bcrypt"
  #
  # password = Crypto::Bcrypt.new "secret", "CJjskaIgXR32DJYjVyNPdA=="
  # password.to_s # => "$2a$11$CJjskaIgXR32DJYjVyNPd./ajV3Yj6GiP0IAI6rR.fMnjRgozqqqG"
  # ```
  def self.new(password : String, salt : String, cost = DEFAULT_COST)
    # We make a clone here to we don't keep a mutable reference to the original string
    passwordb = password.to_unsafe.to_slice(password.bytesize + 1).clone # include leading 0
    saltb = Base64.decode(salt, SALT_SIZE)
    new(passwordb, saltb, cost)
  end

  getter password : Bytes
  getter salt : Bytes
  getter cost : Int32

  # Creates a new `Crypto::Bcrypt` object from the given *password* with *salt* in bytes and *cost*.
  #
  # ```
  # require "crypto/bcrypt"
  #
  # password = Crypto::Bcrypt.new "secret".to_slice, "salt_of_16_chars".to_slice
  # password.digest
  # ```
  def initialize(@password : Bytes, @salt : Bytes, @cost = DEFAULT_COST)
    raise Error.new("Invalid cost") unless COST_RANGE.includes?(cost)
    raise Error.new("Invalid salt size") unless salt.size == SALT_SIZE
    raise Error.new("Invalid password size") unless PASSWORD_RANGE.includes?(password.size)
  end

  @digest : Bytes?

  def digest : Bytes
    @digest ||= hash_password
  end

  @hash : String?

  def to_s : String
    @hash ||= begin
      salt64 = Base64.encode(salt, salt.size)
      digest64 = Base64.encode(digest, digest.size - 1)
      "$2a$%02d$%s%s" % {cost, salt64, digest64}
    end
  end

  def to_s(io : IO) : Nil
    io << to_s
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  delegate to_slice, to: to_s

  private def hash_password
    blowfish = Blowfish.new(BLOWFISH_ROUNDS)
    blowfish.enhance_key_schedule(salt, password, cost)

    cipher = uninitialized UInt32[6]
    cipher.to_slice.copy_from(CIPHER_TEXT.to_slice)
    cdata = cipher.to_unsafe

    0.step(to: 4, by: 2) do |i|
      64.times do
        l, r = blowfish.encrypt_pair(cdata[i], cdata[i + 1])
        cdata[i], cdata[i + 1] = l, r
      end
    end

    ret = Bytes.new(cipher.size * 4)
    j = -1

    cipher.size.times do |i|
      ret[j += 1] = (cdata[i] >> 24).to_u8!
      ret[j += 1] = (cdata[i] >> 16).to_u8!
      ret[j += 1] = (cdata[i] >> 8).to_u8!
      ret[j += 1] = cdata[i].to_u8!
    end

    ret
  end
end

require "./bcrypt/*"
