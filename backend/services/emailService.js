const nodemailer = require('nodemailer');

class EmailService {
  constructor() {
    this.transporter = null;
    this.initializeTransporter();
  }

  initializeTransporter() {
    this.transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS 
      }
    });

    
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
      console.log('⚠️  No email credentials found. Using test mode (codes will be logged to console).');
      this.transporter = null;
    }
  }

  async sendPasswordResetCode(email, code) {
    try {
      if (!this.transporter) {
        console.log(`📧 [EMAIL SERVICE] Password reset code for ${email}: ${code}`);
        console.log(`📧 [EMAIL SERVICE] To enable real emails, set EMAIL_USER and EMAIL_PASS in .env`);
        return { success: true, message: 'Code logged to console (development mode)' };
      }

      const mailOptions = {
        from: process.env.EMAIL_USER,
        to: email,
        subject: 'Password Reset Verification Code - Scan2Suggest',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #00412E; margin-bottom: 10px;">Scan2Suggest</h1>
              <h2 style="color: #666; font-weight: normal;">Password Reset Request</h2>
            </div>
            
            <div style="background-color: #f8f9fa; padding: 30px; border-radius: 10px; text-align: center;">
              <p style="font-size: 16px; color: #333; margin-bottom: 20px;">
                You requested to reset your password. Use the verification code below:
              </p>
              
              <div style="background-color: #00412E; color: white; font-size: 32px; font-weight: bold; padding: 20px; border-radius: 8px; letter-spacing: 4px; margin: 20px 0;">
                ${code}
              </div>
              
              <p style="font-size: 14px; color: #666; margin-top: 20px;">
                This code will expire in 10 minutes for security reasons.
              </p>
            </div>
            
            <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
              <p style="font-size: 12px; color: #999;">
                If you didn't request this password reset, please ignore this email.
              </p>
              <p style="font-size: 12px; color: #999;">
                This is an automated message, please do not reply.
              </p>
            </div>
          </div>
        `
      };

      const info = await this.transporter.sendMail(mailOptions);
      console.log(`📧 [EMAIL SERVICE] Password reset code sent to ${email}`);
      
      return { 
        success: true, 
        message: 'Password reset code sent successfully',
        messageId: info.messageId 
      };

    } catch (error) {
      console.error('📧 [EMAIL SERVICE] Error sending password reset email:', error);
      console.log(`📧 [EMAIL SERVICE] FALLBACK - Password reset code for ${email}: ${code}`);
      
      return { 
        success: true, 
        message: 'Email service unavailable, code logged to console',
        fallback: true 
      };
    }
  }

  async sendEmailVerificationCode(email, code) {
    try {
      // If no transporter configured, just log the code (development mode)
      if (!this.transporter) {
        console.log(`📧 [EMAIL SERVICE] Email verification code for ${email}: ${code}`);
        console.log(`📧 [EMAIL SERVICE] To enable real emails, set EMAIL_USER and EMAIL_PASS in .env`);
        return { success: true, message: 'Code logged to console (development mode)' };
      }

      const mailOptions = {
        from: process.env.EMAIL_USER,
        to: email,
        subject: 'Welcome to Scan2Suggest - Verify Your Email',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #00412E; margin-bottom: 10px;">Welcome to Scan2Suggest!</h1>
              <h2 style="color: #666; font-weight: normal;">Email Verification Required</h2>
            </div>
            
            <div style="background-color: #f0f8f5; padding: 30px; border-radius: 10px; text-align: center;">
              <p style="font-size: 16px; color: #333; margin-bottom: 20px;">
                Thank you for signing up! Please verify your email address using the code below:
              </p>
              
              <div style="background-color: #00412E; color: white; font-size: 32px; font-weight: bold; padding: 20px; border-radius: 8px; letter-spacing: 4px; margin: 20px 0;">
                ${code}
              </div>
              
              <p style="font-size: 14px; color: #666; margin-top: 20px;">
                This verification code will expire in 10 minutes.
              </p>
              
              <p style="font-size: 16px; color: #333; margin-top: 25px;">
                Once verified, you'll be able to access all features of Scan2Suggest!
              </p>
            </div>
            
            <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
              <p style="font-size: 12px; color: #999;">
                If you didn't create an account with us, please ignore this email.
              </p>
              <p style="font-size: 12px; color: #999;">
                This is an automated message, please do not reply.
              </p>
            </div>
          </div>
        `
      };

      const info = await this.transporter.sendMail(mailOptions);
      console.log(`📧 [EMAIL SERVICE] Email verification code sent to ${email}`);
      
      return { 
        success: true, 
        message: 'Email verification code sent successfully',
        messageId: info.messageId 
      };

    } catch (error) {
      console.error('📧 [EMAIL SERVICE] Error sending email verification:', error);
      
      // Fallback to console logging if email fails
      console.log(`📧 [EMAIL SERVICE] FALLBACK - Email verification code for ${email}: ${code}`);
      
      return { 
        success: true, // Still return success so the flow continues
        message: 'Email service unavailable, code logged to console',
        fallback: true 
      };
    }
  }

  
  async sendVerificationCode(email, code) {
    return this.sendPasswordResetCode(email, code);
  }

  async testConnection() {
    if (!this.transporter) {
      return { success: false, message: 'No email transporter configured' };
    }

    try {
      await this.transporter.verify();
      return { success: true, message: 'Email service connection successful' };
    } catch (error) {
      return { success: false, message: `Email service connection failed: ${error.message}` };
    }
  }
}

module.exports = new EmailService();
