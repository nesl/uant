#
# This class is automatically generated by mig. DO NOT EDIT THIS FILE.
# This class implements a Python interface to the 'AlohaMsg'
# message type.
#

import tinyos.message.Message

# The default size of this message type in bytes.
DEFAULT_MESSAGE_SIZE = 3

# The Active Message type associated with this message.
AM_TYPE = 43

class AlohaMsg(tinyos.message.Message.Message):
    # Create a new AlohaMsg of size 3.
    def __init__(self, data="", addr=None, gid=None, base_offset=0, data_length=3):
        tinyos.message.Message.Message.__init__(self, data, addr, gid, base_offset, data_length)
        self.amTypeSet(AM_TYPE)
    
    # Get AM_TYPE
    def get_amType(cls):
        return AM_TYPE
    
    get_amType = classmethod(get_amType)
    
    #
    # Return a String representation of this message. Includes the
    # message type name and the non-indexed field values.
    #
    def __str__(self):
        s = "Message <AlohaMsg> \n"
        try:
            s += "  [src=0x%x]\n" % (self.get_src())
        except:
            pass
        try:
            s += "  [dst=0x%x]\n" % (self.get_dst())
        except:
            pass
        try:
            s += "  [control=0x%x]\n" % (self.get_control())
        except:
            pass
        return s

    # Message-type-specific access methods appear below.

    #
    # Accessor methods for field: src
    #   Field type: short
    #   Offset (bits): 0
    #   Size (bits): 8
    #

    #
    # Return whether the field 'src' is signed (False).
    #
    def isSigned_src(self):
        return False
    
    #
    # Return whether the field 'src' is an array (False).
    #
    def isArray_src(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'src'
    #
    def offset_src(self):
        return (0 / 8)
    
    #
    # Return the offset (in bits) of the field 'src'
    #
    def offsetBits_src(self):
        return 0
    
    #
    # Return the value (as a short) of the field 'src'
    #
    def get_src(self):
        return self.getUIntElement(self.offsetBits_src(), 8, 1)
    
    #
    # Set the value of the field 'src'
    #
    def set_src(self, value):
        self.setUIntElement(self.offsetBits_src(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'src'
    #
    def size_src(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'src'
    #
    def sizeBits_src(self):
        return 8
    
    #
    # Accessor methods for field: dst
    #   Field type: short
    #   Offset (bits): 8
    #   Size (bits): 8
    #

    #
    # Return whether the field 'dst' is signed (False).
    #
    def isSigned_dst(self):
        return False
    
    #
    # Return whether the field 'dst' is an array (False).
    #
    def isArray_dst(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'dst'
    #
    def offset_dst(self):
        return (8 / 8)
    
    #
    # Return the offset (in bits) of the field 'dst'
    #
    def offsetBits_dst(self):
        return 8
    
    #
    # Return the value (as a short) of the field 'dst'
    #
    def get_dst(self):
        return self.getUIntElement(self.offsetBits_dst(), 8, 1)
    
    #
    # Set the value of the field 'dst'
    #
    def set_dst(self, value):
        self.setUIntElement(self.offsetBits_dst(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'dst'
    #
    def size_dst(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'dst'
    #
    def sizeBits_dst(self):
        return 8
    
    #
    # Accessor methods for field: control
    #   Field type: short
    #   Offset (bits): 16
    #   Size (bits): 8
    #

    #
    # Return whether the field 'control' is signed (False).
    #
    def isSigned_control(self):
        return False
    
    #
    # Return whether the field 'control' is an array (False).
    #
    def isArray_control(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'control'
    #
    def offset_control(self):
        return (16 / 8)
    
    #
    # Return the offset (in bits) of the field 'control'
    #
    def offsetBits_control(self):
        return 16
    
    #
    # Return the value (as a short) of the field 'control'
    #
    def get_control(self):
        return self.getUIntElement(self.offsetBits_control(), 8, 1)
    
    #
    # Set the value of the field 'control'
    #
    def set_control(self, value):
        self.setUIntElement(self.offsetBits_control(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'control'
    #
    def size_control(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'control'
    #
    def sizeBits_control(self):
        return 8
    